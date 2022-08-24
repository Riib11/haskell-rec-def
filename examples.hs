{-|

This file contains a few examples of using this library.

The 'PAll' has a few functions that look like ordinary boolean functions

>>> :t pAllTrue
pAllTrue :: PAll
>>> :t pAllFalse
pAllFalse :: PAll
>>> :t (&&&)
(&&&) :: PAll -> PAll -> PAll
>>> getPAll pAllTrue
True
>>> getPAll pAllFalse
False
>>> getPAll (pAllFalse &&& pAllTrue)
False
>>> getPAll (pAllTrue &&& pAllTrue)
True
>>> getPAll (pand [pAllTrue,  pAllFalse, pAllTrue])
False

But the difference is that it allows recusive equations.
With normal 'Bool', the following goes into a loop:
>>> withTimeout $ let x = and [y]; y = and [x, False] in x
*** Exception: timed out

But with 'PAll', this works!
>>> let x = pand [y]; y = pand [x, pAllFalse] in getPAll x
False
>>> let x = pand [y]; y = pand [x, pAllTrue] in getPAll x
True
>>> let x = pand [y]; y = pand [x] in getPAll x
True

You will notice that API for 'PAll' does not include all boolean functions.
Essentially, it only has the constants ('pAllTrue' and 'pAllFalse'), and
conjunction. These are the monotone functions if we order the Booleans as
'True' ≤ 'False'.

We can also consider the dual order, embodied in the type 'PAny':

>>> let x = por [y]; y = por [x, pAnyFalse] in getPAny x
False
>>> let x = por [y]; y = por [x, pAnyTrue] in getPAny x
True
>>> let x = por [y]; y = por [x] in getPAny x
False

The negation is actually monotone when we go from one of these to the other, so we have
>>> :t notAll
notAll :: PAll -> PAny
>>> :t notAny
notAny :: PAny -> PAll

and we can mix the different types in the same computation:
>>> :{
  let x = notAny y &&& notAny z
      y = notAll x ||| z
      z = pAnyTrue
  in (getPAll x, getPAny y, getPAny z)
 :}
(False,True,True)

>>> :{
  let x = notAny y &&& notAny z
      y = notAll x ||| z
      z = pAnyFalse
  in (getPAll x, getPAny y, getPAny z)
 :}
(True,False,False)

We do not have to stop with booleans, and can define similar APIs for other data stuctures, e.g. sets:

Again we can describe sets recursively, using the monotone functions 'pEmpty', 'pInsert' and 'pUnion'

>>> :{
  let s1 = pInsert 23 s2
      s2 = pInsert 42 s1
  in getPSet s1
 :}
fromList [23,42]

Here is a slightly larger example, where we can can use this API to elegantly
calculate the reachable nodes in a graph, using a knot-tying approach, even if
the graph has cycles:
>>> :{
   -- Missing from Data.Array
   imap :: Ix i => (i -> e -> e') -> Array i e -> Array i e'
   imap f a = array (bounds a) [(i, f i x) | (i,x) <- assocs a]
 :}

>>> :{
   reachable :: Graph -> Array Vertex (S.Set Vertex)
   reachable g = fmap getPSet psets
     where
       psets :: Array Vertex (PSet Vertex)
       psets = imap (\v vs -> pInsert v (pUnions [ psets ! v' | v' <- vs ])) g
 :}

>>> let graph = buildG (1,3) [(1,2),(1,3),(2,1)]
>>> reachable graph ! 1
fromList [1,2,3]
>>> reachable graph ! 3
fromList [3]


Of course, the magic stops somewhere: Just like with the usual knot-tying
tricks, you still have to makesure to be lazy enough. In particular, you should
not peek at the value (e.g. using 'getPAll') while you are building the graph:
>>> :{
    withTimeout $
      let x = pand [x, if getPAll y then z else pAllTrue]
          y = pand [x, pAllTrue]
          z = pAllFalse
      in getPAll y
    :}
*** Exception: timed out

Similarly, you have to make sure you recurse through one of these functions:
>>> withTimeout $ let x = x in getPAll x
*** Exception: timed out
>>> withTimeout $ let x = x &&& x in getPAll x
True

-}

module Examples where
import Data.Recursive.Bool
import Data.Recursive.Set

import System.Timeout
import Control.Exception
import Data.Maybe
import Data.Graph
import Data.Array
import qualified Data.Set as S
import GHC.Err


withTimeout a =
    fromMaybe (errorWithoutStackTrace "timed out") <$>
        timeout 1000000 (evaluate a)
