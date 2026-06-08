# TODO - Incremental dataset building

- [x] Update `python/dataset_builder.py` to support incremental mode:
  - [x] Load existing `dataset/tradingai_dataset.parquet` if present
  - [x] Build new trades from `data/` as today
  - [x] Merge with existing dataset using a stable key (`position_ticket`)
  - [x] Prefer newest row values for duplicates
  - [x] Save back to CSV and Parquet
- [x] Add CLI flag like `--incremental/--no-incremental` (default to incremental)
- [x] Add a safety flag or logging to show how many new vs duplicate trades were merged
- [ ] Run `python python/dataset_builder.py ...` twice to confirm rows don’t drop when `data/` is incomplete
