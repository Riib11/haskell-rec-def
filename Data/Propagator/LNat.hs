module Data.Propagator.LNat
  ( LNat,
    newLNat,
    newTopLNat,
    setTop,
    whenTop,
    implies,
    isTop,
  )
where

import Control.Concurrent.MVar
import Control.Exception
import Data.Propagator.Class


newtype LNat_ = LNat (MVar_ MaybeTop_)

