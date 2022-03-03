-- Alfred-Margaret: Fast Aho-Corasick string searching
-- Copyright 2022 Channable
--
-- Licensed under the 3-clause BSD license, see the LICENSE file in the
-- repository root.

{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

module Data.Text.Utf8.AhoCorasickSpec where

import Data.Primitive (byteArrayFromList)
import Data.String (IsString, fromString)
import qualified Data.Text.Utf8 as Utf8
import qualified Data.Text.Utf8.AhoCorasick.Automaton as Aho
import Test.Hspec (Expectation, Spec, describe, it, shouldBe)

spec :: Spec
spec = do
    -- Ensure that helper functions are actually helping
    -- Examples are from https://en.wikipedia.org/wiki/UTF-8
    describe "IsString ByteArray" $ do
        it "encodes the dollar sign" $ utf8Test "$" [0x24]
        it "encodes the euro sign" $ utf8Test "€" [0xe2, 0x82, 0xac]
        it "encodes the pound sign" $ utf8Test "£" [0xc2, 0xa3]
        it "encodes Hwair" $ utf8Test "𐍈" [0xf0, 0x90, 0x8d, 0x88]
        it "encodes all of the above" $ utf8Test "$€£𐍈" [0x24, 0xe2, 0x82, 0xac, 0xc2, 0xa3, 0xf0, 0x90, 0x8d, 0x88]

    describe "case sensitive search" $ do
        describe "countMatches" $ do
            it "counts the right number of matches in a basic example" $ do
                countMatches Aho.CaseSensitive ["abc", "rst", "xyz"] "abcdefghijklmnopqrstuvwxyz" `shouldBe` 3

            it "counts the right number of matches in an example with 1-, 2-, 3- and 4-code unit code points" $ do
                countMatches Aho.CaseSensitive ["$", "£"] "$€£𐍈" `shouldBe` 2

    describe "case insensitive search" $ do
        describe "countMatches" $ do
            it "counts the right number of matches in a basic example" $ do
                countMatches Aho.IgnoreCase ["abc", "rst", "xyz"] "abcdefghijklmnopqrstuvwxyz" `shouldBe` 3

            it "does not work with uppercase needles" $ do
                countMatches Aho.IgnoreCase ["ABC", "Rst", "xYZ"] "abcdefghijklmnopqrstuvwxyz" `shouldBe` 0

            it "works with characters that are not in ASCII" $ do
                countMatches Aho.IgnoreCase ["groß", "öffnung", "tür"] "Großfräsmaschinenöffnungstür" `shouldBe` 3

-- helpers

instance IsString Utf8.Text where
    fromString = Utf8.pack

utf8Test :: String -> [Utf8.CodeUnit] -> Expectation
utf8Test str byteList = fromString str `shouldBe` Utf8.Text (byteArrayFromList byteList) 0 (length byteList)

-- From ./benchmark
countMatches :: Aho.CaseSensitivity -> [Utf8.Text] -> Utf8.Text -> Int
{-# NOINLINE countMatches #-}
countMatches caseSensitivity needles haystack = case needles of
  [] -> 0
  _  ->
    let
      ac = Aho.build $ zip (map Utf8.unpackUtf8 needles) (repeat ())
      onMatch !n _match = Aho.Step (n + 1)
    in
      Aho.runWithCase caseSensitivity 0 onMatch ac haystack