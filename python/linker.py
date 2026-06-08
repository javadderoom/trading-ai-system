from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from models import TradeRecord, TimeEvent, TrainingSample


def _resolve_screenshot_path(screenshots_dir: Path, manifest_entry: str) -> Optional[Path]:
    p = screenshots_dir / manifest_entry
    return p if p.exists() else None


def link_screenshots(trade: TradeRecord, screenshots_dir: Path) -> TradeRecord:
    valid_entry = []
    for shot in trade.entry_screenshots:
        if _resolve_screenshot_path(screenshots_dir, shot):
            valid_entry.append(shot)
    valid_exit = []
    for shot in trade.exit_screenshots:
        if _resolve_screenshot_path(screenshots_dir, shot):
            valid_exit.append(shot)
    trade.entry_screenshots = valid_entry
    trade.exit_screenshots = valid_exit
    return trade


def find_context_snapshots(
    trade: TradeRecord,
    time_events: list[TimeEvent],
    hours_before: float = 1.0,
    hours_after: float = 1.0,
) -> tuple[list[TimeEvent], list[TimeEvent]]:
    pre: list[TimeEvent] = []
    post: list[TimeEvent] = []

    cutoff_before = trade.entry_time - timedelta(hours=hours_before)
    cutoff_after: Optional[datetime] = None
    if trade.exit_time is not None:
        cutoff_after = trade.exit_time + timedelta(hours=hours_after)

    for te in time_events:
        if te.symbol != trade.symbol:
            continue
        if cutoff_before <= te.dt <= trade.entry_time:
            pre.append(te)
        if trade.exit_time is not None and cutoff_after is not None and trade.exit_time <= te.dt <= cutoff_after:
            post.append(te)

    return pre, post


def build_training_sample(
    trade: TradeRecord,
    time_events: list[TimeEvent],
    screenshots_dir: Path,
    hours_before: float = 1.0,
    hours_after: float = 1.0,
) -> TrainingSample:
    trade = link_screenshots(trade, screenshots_dir)
    pre, post = find_context_snapshots(trade, time_events, hours_before, hours_after)
    return TrainingSample(
        trade=trade,
        pre_entry_snapshots=pre,
        post_exit_snapshots=post,
    )
