import Test.Framework (defaultMain, testGroup)
import Test.Framework.Providers.HUnit
import Test.Framework.Providers.QuickCheck2 (testProperty)
import Test.QuickCheck
import Test.QuickCheck.Monadic

import qualified Data.ByteString as B
import qualified Data.Enumerator as E
import qualified Data.Enumerator.List as EL
import Data.Word
import Codec.Compression.Lzma.Enumerator

main = defaultMain tests

tests =
  [ testGroup "Encode Group" encodeTests
  , testGroup "Decode Group" decodeTests
  , testGroup "Chained Group" chainedTests
  ]

encodeTests = [testProperty "compressAndDiscard" prop_compressAndDiscard]
decodeTests = []
chainedTests = [testProperty "chain" prop_chain]

someString :: Gen B.ByteString
someString = do
  val <- listOf $ elements [0..255::Word8] 
  return $ B.pack val

someBigString :: Gen B.ByteString
someBigString = resize (8*1024) someString

dropAll :: Monad m => E.Iteratee a m ()
dropAll = EL.dropWhile (const True)

prop_compressAndDiscard :: Property
prop_compressAndDiscard = monadicIO $ forAllM someBigString $ \ str -> do
  run $ E.run_ $ E.enumList 2 [str] E.$$ E.joinI (compress Nothing E.$$ dropAll)

prop_chain :: Property
prop_chain = monadicIO $ forAllM someBigString $ \ str -> do
  blob <- run $ E.run_ $ E.enumList 2 [str] E.$$ E.joinI (compress Nothing E.$$ EL.consume)
  str' <- run $ E.run_ $ E.enumList 2 blob E.$$ E.joinI (decompress Nothing E.$$ EL.consume)
  return $ str == B.concat str'
