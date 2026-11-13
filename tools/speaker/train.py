"""Reproducible stdlib-only sparse embedding network; no training runtime ships.
Run: py -3 tools/speaker/train.py (evaluation is a separate --evaluate command).
"""
import argparse
import array
import collections
import hashlib
import json
import math
from pathlib import Path
import random
import re
import sys
import time
from corpus import TRAIN, DEV, rows

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = ROOT / 'sim' / 'speaker_model'
DIM = 24

def features(text):
    words = re.sub('[^a-z0-9]+', ' ', text[:120].lower()).split()
    result = []
    for word in words:
        result.extend(['w:' + word] * 3)
        padded = '<' + word + '>'
        for n in (3, 4, 5):
            result.extend('c:' + padded[i:i+n] for i in range(len(padded)-n+1))
    result.extend('b:' + a + '_' + b for a, b in zip(words, words[1:]))
    return result

def encode(text, vocab):
    raw = features(text)
    known = [vocab[f] for f in raw if f in vocab]
    return known, len(known) / max(1, len(raw))

def forward(ids, emb, out, bias):
    scale = 1.0 / math.sqrt(max(1, len(ids)))
    h = [0.0] * DIM
    for i in ids:
        e = emb[i]
        for j in range(DIM):
            h[j] += e[j] * scale
    h = [math.tanh(v) for v in h]
    scores = [b + sum(w*v for w, v in zip(row, h)) for row, b in zip(out, bias)]
    peak = max(scores)
    p = [math.exp(s-peak) for s in scores]
    total = sum(p)
    return h, [v/total for v in p]

def prediction(text, meta, emb, out, bias):
    ids, coverage = encode(text, meta['vocab'])
    _, p = forward(ids, emb, out, bias)
    order = sorted(range(len(p)), key=p.__getitem__, reverse=True)
    first, second = order[:2]
    raw = meta['labels'][first]
    accepted = bool(ids) and coverage >= meta['coverage'] and p[first] >= meta['confidence'] and p[first]-p[second] >= meta['margin'] and raw != 'unknown'
    return dict(intent=raw if accepted else 'unknown', raw=raw, confidence=p[first],
                secondary=meta['labels'][second], margin=p[first]-p[second], coverage=coverage)

def save(meta, emb, out, bias):
    DEST.mkdir(parents=True, exist_ok=True)
    values = array.array('f', [v for row in emb for v in row] + [v for row in out for v in row] + bias)
    if sys.byteorder != 'little':
        values.byteswap()
    (DEST / 'weights.bin').write_bytes(values.tobytes())
    meta['weights_sha256'] = hashlib.sha256((DEST / 'weights.bin').read_bytes()).hexdigest()
    (DEST / 'model.json').write_text(json.dumps(meta, separators=(',', ':')), encoding='utf-8')

def load():
    meta = json.loads((DEST / 'model.json').read_text())
    v = array.array('f')
    v.frombytes((DEST / 'weights.bin').read_bytes())
    if sys.byteorder != 'little':
        v.byteswap()
    n = len(meta['vocab'])
    emb = [list(v[i*DIM:(i+1)*DIM]) for i in range(n)]
    out = [list(v[(n+i)*DIM:(n+i+1)*DIM]) for i in range(len(meta['labels']))]
    bias = list(v[(n+len(out))*DIM:])
    return meta, emb, out, bias

def train():
    start = time.perf_counter()
    rng = random.Random(1808)
    training, dev = rows(TRAIN), rows(DEV)
    normalize = lambda text: re.sub('[^a-z0-9]+', ' ', text.lower()).strip()
    assert not ({normalize(r['text']) for r in training} & {normalize(r['text']) for r in dev}), 'Training/development overlap'
    vocab = {f: i for i, f in enumerate(sorted({f for r in training for f in features(r['text'])}))}
    labels = sorted({r['intent'] for r in training})
    data = [(encode(r['text'], vocab)[0], labels.index(r['intent'])) for r in training]
    emb = [[rng.uniform(-0.08, 0.08) for _ in range(DIM)] for _ in vocab]
    out = [[rng.uniform(-0.08, 0.08) for _ in range(DIM)] for _ in labels]
    bias = [0.0] * len(labels)
    meta = dict(version=1, architecture='sparse-embedding-tanh-softmax', dim=DIM, vocab=vocab,
                labels=labels, confidence=0.46, margin=0.13, coverage=0.48, seed=1808,
                training_rows=len(training), development_rows=len(dev), max_characters=120)
    best = -1.0
    for epoch in range(180):
        rng.shuffle(data)
        lr = 0.045 * (1.0 - epoch / 225.0)
        for ids, label in data:
            h, p = forward(ids, emb, out, bias)
            p[label] -= 1.0
            grad = [sum(p[k]*out[k][j] for k in range(len(labels))) * (1-h[j]*h[j]) for j in range(DIM)]
            for k, row in enumerate(out):
                g = lr*p[k]
                for j in range(DIM):
                    row[j] -= g*h[j]
                bias[k] -= g
            step = lr / math.sqrt(max(1, len(ids)))
            for i in ids:
                row = emb[i]
                for j in range(DIM):
                    row[j] -= step*grad[j]
        if epoch % 10 == 9:
            correct = 0
            for r in dev:
                _, p = forward(encode(r['text'], vocab)[0], emb, out, bias)
                correct += labels[max(range(len(p)), key=p.__getitem__)] == r['intent']
            score = correct/len(dev)
            if score > best:
                best = score
                meta['epoch'] = epoch+1
                meta['development_accuracy'] = best
                save(meta, emb, out, bias)
            print(f'Epoch {epoch+1}: dev top-1 {score:.1%}, best {best:.1%}', flush=True)
    print(f'Trained in {time.perf_counter()-start:.1f}s; selected checkpoint by development accuracy only.')
    calibrate()

def calibrate():
    meta, emb, out, bias = load()
    predictions = [(r['intent'], prediction(r['text'], meta, emb, out, bias)) for r in rows(DEV)]
    best = None
    for threshold in (0.30, 0.35, 0.40, 0.46, 0.50, 0.55):
        for margin in (0.08, 0.10, 0.13, 0.18, 0.22):
            cost = 0
            for expected, p in predictions:
                accept = p['raw'] != 'unknown' and p['coverage'] >= meta['coverage'] and p['confidence'] >= threshold and p['margin'] >= margin
                if expected == 'unknown':
                    cost += 5 if accept else 0
                elif not accept:
                    cost += 1
                elif expected != p['raw']:
                    cost += 4
            candidate = (cost, -threshold, -margin)
            if best is None or candidate < best:
                best = candidate
    meta['confidence'], meta['margin'] = -best[1], -best[2]
    meta['calibration'] = 'development-only: wrong intent cost 4, unsupported acceptance 5, abstention 1'
    save(meta, emb, out, bias)
    print(f'Development rejection thresholds: p >= {meta["confidence"]}, margin >= {meta["margin"]}')

def evaluate():
    meta, emb, out, bias = load()
    test = json.loads((HERE / 'evaluation.json').read_text())
    seen = {r['text'].lower().strip('?.! ') for r in rows(TRAIN)+rows(DEV)}
    results = []
    start = time.perf_counter()
    for label, questions in test.items():
        for text in questions:
            result = prediction(text, meta, emb, out, bias)
            result.update(text=text, expected=label, unseen=text.lower().strip('?.! ') not in seen)
            results.append(result)
    unseen = [r for r in results if r['unseen']]
    known = [r for r in unseen if r['expected'] != 'unknown']
    unknown = [r for r in unseen if r['expected'] == 'unknown']
    report = dict(training_rows=meta['training_rows'], development_rows=meta['development_rows'],
                  test_rows=len(results), unseen_rows=len(unseen), anchor_rows=len(results)-len(unseen),
                  unseen_top1_accuracy=sum(r['raw']==r['expected'] for r in unseen)/len(unseen),
                  unseen_accepted_accuracy=sum(r['intent']==r['expected'] for r in known)/len(known),
                  unseen_known_coverage=sum(r['intent']!='unknown' for r in known)/len(known),
                  unknown_rejection=sum(r['intent']=='unknown' for r in unknown)/len(unknown),
                  model_bytes=sum(p.stat().st_size for p in DEST.iterdir() if p.suffix in ('.json','.bin')),
                  python_eval_ms=(time.perf_counter()-start)*1000, results=results)
    (HERE / 'results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='results'}, indent=2))
    for r in results:
        if r['intent'] != r['expected']:
            print(f"{r['expected']:12} -> {r['intent']:12} (raw {r['raw']}, p={r['confidence']:.2f}): {r['text']}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--evaluate', action='store_true')
    parser.add_argument('--calibrate', action='store_true')
    args = parser.parse_args()
    evaluate() if args.evaluate else calibrate() if args.calibrate else train()
