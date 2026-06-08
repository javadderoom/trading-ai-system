from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Optional

from models import TradeEvent, TimeEvent, TradeRecord


def load_trade_events(data_dir: Path) -> list[TradeEvent]:
    events: list[TradeEvent] = []
    for f in sorted(data_dir.glob("trade_events_*.jsonl")):
        for line in f.read_text("utf-8").strip().splitlines():
            line = line.strip()
            if not line:
                continue
            data = json.loads(line)
            events.append(TradeEvent(**data))
    return events


def load_time_events(data_dir: Path) -> list[TimeEvent]:
    events: list[TimeEvent] = []
    for f in sorted(data_dir.glob("time_events_*.jsonl")):
        for line in f.read_text("utf-8").strip().splitlines():
            line = line.strip()
            if not line:
                continue
            data = json.loads(line)
            events.append(TimeEvent(**data))
    return events


def _parse_dt(s: str) -> datetime:
    return datetime.strptime(s, "%Y.%m.%d %H:%M:%S")


def _build_trade_record(position_ticket: int, deals: list[TradeEvent]) -> Optional[TradeRecord]:
    entries = [d for d in deals if d.phase == "entry"]
    exits = [d for d in deals if d.phase == "exit"]

    if not entries:
        return None

    first_entry = entries[0]

    entry_price = sum(d.price * d.volume for d in entries) / sum(d.volume for d in entries)
    entry_volume = sum(d.volume for d in entries)

    exit_price: Optional[float] = None
    if exits:
        exit_volumes = sum(abs(d.volume) for d in exits)
        exit_price = sum(d.price * abs(d.volume) for d in exits) / exit_volumes if exit_volumes > 0 else 0.0

    profit = sum(d.profit for d in deals)

    sl = first_entry.sl if first_entry.sl != 0.0 else None
    tp = first_entry.tp if first_entry.tp != 0.0 else None

    rr: Optional[float] = None
    if sl is not None and tp is not None and entry_price > 0:
        if first_entry.deal_type == "buy":
            risk = entry_price - sl
            reward = tp - entry_price
        else:
            risk = sl - entry_price
            reward = entry_price - tp
        if risk > 0:
            rr = round(reward / risk, 2)

    entry_time = _parse_dt(first_entry.time_utc)
    exit_time = _parse_dt(exits[-1].time_utc) if exits else None

    duration: Optional[float] = None
    if exit_time and entry_time:
        duration = round((exit_time - entry_time).total_seconds() / 60.0, 1)

    win_loss: Optional[str] = None
    if exits:
        if profit > 0:
            win_loss = "win"
        elif profit < 0:
            win_loss = "loss"
        else:
            win_loss = "breakeven"
    else:
        win_loss = "open"

    entry_shots: list[str] = []
    for d in entries:
        if d.screenshots:
            entry_shots.extend(d.screenshots.split("|"))

    exit_shots: list[str] = []
    for d in exits:
        if d.screenshots:
            exit_shots.extend(d.screenshots.split("|"))

    return TradeRecord(
        position_ticket=position_ticket,
        symbol=first_entry.symbol,
        deal_type=first_entry.deal_type,
        entry_time=entry_time,
        exit_time=exit_time,
        entry_price=round(entry_price, first_entry.price_digits),
        exit_price=round(exit_price, first_entry.price_digits) if exit_price is not None else None,
        volume=entry_volume,
        profit=round(profit, 2),
        sl=round(sl, first_entry.price_digits) if sl is not None else None,
        tp=round(tp, first_entry.price_digits) if tp is not None else None,
        rr=rr,
        win_loss=win_loss,
        duration_minutes=duration,
        entry_screenshots=entry_shots,
        exit_screenshots=exit_shots,
        entry_deal_tickets=[d.deal_ticket for d in entries],
        exit_deal_tickets=[d.deal_ticket for d in exits],
    )


def parse_trades(trade_events: list[TradeEvent]) -> list[TradeRecord]:
    by_position: dict[int, list[TradeEvent]] = defaultdict(list)
    for te in trade_events:
        by_position[te.position_ticket].append(te)

    records: list[TradeRecord] = []
    for pos_ticket, deals in by_position.items():
        record = _build_trade_record(pos_ticket, deals)
        if record is not None:
            records.append(record)

    records.sort(key=lambda r: r.entry_time)
    return records
