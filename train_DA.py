#!/usr/bin/env python3
from src.train.train_DA import *

if __name__ == '__main__':
    try:
        main()
    except NameError as exc:
        raise SystemExit('src.train.train_DA does not expose a main() function yet. Run with: python -m src.train.train_DA') from exc
