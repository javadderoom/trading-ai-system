from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class TimeEvent:
    event_type: str
    snapshot_id: str
    file_stamp: str
    symbol: str
    time_utc: str
    screenshots: str
    digits: int
    bid: float
    ask: float
    spread_points: int
    bar_m1: str
    bar_m5: str
    bar_m15: str
    bar_h1: str
    bar_h4: str
    bar_d1: str

    @property
    def dt(self) -> datetime:
        return datetime.strptime(self.time_utc, "%Y.%m.%d %H:%M:%S")


@dataclass
class TradeEvent:
    event_type: str
    event_id: str
    file_stamp: str
    symbol: str
    comment: str
    screenshots: str
    phase: str
    deal_type: str
    deal_entry: str
    time_utc: str
    deal_ticket: int
    order_ticket: int
    position_ticket: int
    magic: int
    price: float
    price_digits: int
    volume: float
    profit: float
    sl: float = 0.0
    tp: float = 0.0

    @property
    def dt(self) -> datetime:
        return datetime.strptime(self.time_utc, "%Y.%m.%d %H:%M:%S")


@dataclass
class TradeRecord:
    position_ticket: int
    symbol: str
    deal_type: str
    entry_time: datetime
    exit_time: Optional[datetime]
    entry_price: float
    exit_price: Optional[float]
    volume: float
    profit: float
    sl: Optional[float]
    tp: Optional[float]
    rr: Optional[float]
    win_loss: Optional[str]
    duration_minutes: Optional[float]
    entry_screenshots: list[str] = field(default_factory=list)
    exit_screenshots: list[str] = field(default_factory=list)
    entry_deal_tickets: list[int] = field(default_factory=list)
    exit_deal_tickets: list[int] = field(default_factory=list)


@dataclass
class TrainingSample:
    trade: TradeRecord
    pre_entry_snapshots: list[TimeEvent] = field(default_factory=list)
    post_exit_snapshots: list[TimeEvent] = field(default_factory=list)
