#!/usr/bin/env python3
"""Compare real phase-6 benchmark outputs; never supplies placeholder results."""
from pathlib import Path
import json
import statistics

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / 'evidence'
before = json.loads((EVIDENCE / 'phase6-core-before.json').read_text())
after = json.loads((EVIDENCE / 'phase6-core-after.json').read_text())
assert before['dataset'] == after['dataset'] and before['entries'] == after['entries'] == 10_000
assert before['invariants'] == after['invariants'], 'Financial results changed'

rows = []
for name, original in before['measurements'].items():
    old = original['medianMS']
    new = after['measurements'][name]['medianMS']
    rows.append({'operation': name, 'beforeMS': old, 'afterMS': new,
                 'reductionPercent': (1 - new / old) * 100})

storage_before = json.loads((EVIDENCE / 'phase6-storage-before.json').read_text())
storage_after = json.loads((EVIDENCE / 'phase6-storage-after.json').read_text())
for name in ['open', 'change']:
    old = [item for item in storage_before if item['operation'] == name]
    new = [item for item in storage_after if item['operation'] == name]
    if name == 'open':
        old = old[1:]  # Initial synthetic seeding is not a reopen.
        new = new[1:]
        assert len(old) == len(new) == 3
    assert old and new
    a = statistics.median(item['milliseconds'] for item in old)
    b = statistics.median(item['milliseconds'] for item in new)
    rows.append({'operation': 'storage_' + name, 'beforeMS': a, 'afterMS': b,
                 'reductionPercent': (1 - b / a) * 100,
                 'samplesBefore': len(old), 'samplesAfter': len(new),
                 'encodedRowsBefore': [item['encodedRows'] for item in old],
                 'encodedRowsAfter': [item['encodedRows'] for item in new]})

thresholds = {'validate_10000': 100, 'build_read_index': 50, 'monthly_report': 50,
              'storage_open': 1000, 'storage_change': 250}
result = {'financialInvariantsEqual': True, 'dataset': before['dataset'],
          'entries': before['entries'], 'coreMode': 'Release, macOS', 'storageMode': 'Debug, iOS Simulator',
          'measurements': rows,
          'objectivesMS': thresholds,
          'objectivesMet': {row['operation']: row['afterMS'] < thresholds[row['operation']]
                            for row in rows if row['operation'] in thresholds},
          'limitations': ['Seven core samples after one warmup; three storage reopens and one change.',
                          'No claim about physical iPhone startup, application memory, or battery use.']}
(EVIDENCE / 'phase6-comparison.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
for row in rows:
    print(f"{row['operation']}: {row['beforeMS']:.3f} -> {row['afterMS']:.3f} ms ({row['reductionPercent']:.1f}% reduction)")
print('Financial invariants: PASS')
print('Objectives:', result['objectivesMet'])
