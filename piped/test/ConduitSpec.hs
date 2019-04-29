{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE LambdaCase #-}

module ConduitSpec
  ( module ConduitSpec
  , C.runConduit
  , P.runPipe
  ) where

import qualified Data.Conduit as C
import qualified Control.Pipe as P
import Control.Monad.State

import Data.Void
import Test.Tasty
import Test.Tasty.HUnit

import Debug.Trace

import TestPipes

alloc n act = do
  act <* lift (modify (n:))

simple1 = pure 1
simple2 = pure 1

ya1 = alloc 2 (yield 1) .|| alloc 1 await
ya2 = alloc 1 (yield 1) .|| alloc 1 await

sl1 = (yield True >> yield False) .|| sinkList
sl2 = (yield True >> yield False) .|| sinkList

t1 = pure () .|| (await >> pure ()) .|| (await >> pure True)
t2 = pure () .|| (await >> pure ()) .|| (await >> pure True)

unit1 = replicateM 2 await
unit2 = replicateM 2 await

rec1 n = yield () .|| (await >> recurse rec1 n)
rec2 n = yield () .|| (await >> recurse rec2 n)
recurse ma 0 = await >> pure True
recurse ma n = ma (n-1)

memptyPipe1 = alloc 1 (yield () >> yield ()) .|| mempty :: C.ConduitT () Void (State [Int]) ()
memptyPipe2 = alloc 1 (yield () >> yield ()) .|| mempty

test_units :: TestTree
test_units = testGroup "Conduit spec"
  [ testCompare "simple" simple1 simple2
  , testCompare "yield await" ya1 ya2
  , testCompare "sinkList" sl1 sl2
  , testCompare "termination" t1 t2
  , testCompare "() inputs" unit1 unit2
  , testCompare "resursive pipe" (rec1 100) (rec2 100)
  , testCompare "mempty pipe" (memptyPipe1) (memptyPipe2)
  ]

testCompare :: (Eq a, Show a)
            => String -> C.ConduitT () Void (State [Int]) a
                      -> P.Pipe     () Void (State [Int]) a
                      -> TestTree
testCompare s p p' = testCase s $ do
  let pr = runState (P.runPipe    p') []
  let cr = runState (C.runConduit p ) []
  cr @?= pr