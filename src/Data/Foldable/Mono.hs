{-# LANGUAGE BangPatterns      #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies      #-}

module Data.Foldable.Mono (
    MFoldable (..)
) where

import Prelude hiding (foldl, foldl1, foldr, foldr1)
import Data.Maybe
import Data.Monoid

-- for instances
import qualified Data.Foldable as Fold
import qualified Data.ByteString as B
import qualified Data.ByteString.Internal as B
import qualified Data.ByteString.Unsafe as B
import Data.Word (Word8)

import Foreign.Storable (Storable (..))
import System.IO.Unsafe (unsafePerformIO)
import Control.Monad.ST (ST)

import qualified Data.Text as T
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Unboxed as VU

{- | Monomorphic data structures that can be folded
     Minimal complete definition: 'foldMap' or 'foldr'
-}
class MFoldable t where
    type (Elem t) :: *

    {- | Map each element to a monoid and combine the results -}
    foldMap :: Monoid m => (Elem t -> m) -> t -> m
    foldMap f = foldr (mappend . f) mempty

    {- | Left-associative fold -}
    foldl :: (a -> Elem t -> a) -> a -> t -> a
    foldl f z t = appEndo (getDual (foldMap (Dual . Endo . flip f) t)) z

    {- | Strict version of 'foldl'. -}
    foldl' :: (a -> Elem t -> a) -> a -> t -> a
    -- This implementation from Data.Foldable
    foldl' f a xs = foldr f' id xs a
        where f' x k z = k $! f z x

    -- | A variant of 'foldl' with no base case.  Requires at least 1
    -- list element.
    foldl1 :: (Elem t -> Elem t -> Elem t) -> t -> Elem t
    -- This implementation from Data.Foldable
    foldl1 f xs = fromMaybe (error "fold1: empty structure")
                    (foldl mf Nothing xs)
           where mf Nothing y = Just y
                 mf (Just x) y = Just (f x y)

    {- | Right-associative fold -}
    foldr :: (Elem t -> b -> b) -> b -> t -> b
    foldr f z t = appEndo (foldMap (Endo . f) t) z

    -- | Strict version of 'foldr'
    foldr' :: (Elem t -> b -> b) -> b -> t -> b
    -- This implementation from Data.Foldable
    foldr' f a xs = foldl f' id xs a
        where f' k x z = k $! f x z

    -- | Like 'foldr', but with no starting value
    foldr1 :: (Elem t -> Elem t -> Elem t) -> t -> Elem t
    -- This implementation from Data.Foldable
    foldr1 f xs = fromMaybe (error "foldr1: empty structure")
                    (foldr mf Nothing xs)
           where mf x Nothing = Just x
                 mf x (Just y) = Just (f x y)

    -- | Monadic left fold
    foldM :: (Monad m, MFoldable t) => (a -> Elem t -> m a) -> a -> t -> m a
    foldM f z xs = foldr (\x rest a -> f a x >>= rest) return xs z
 
    -- | Monadic map, discarding results
    mapM_ :: (MFoldable t, Monad m) => (Elem t -> m b) -> t -> m ()
    mapM_ f = foldr ((>>) . f) (return ())

instance (Fold.Foldable t) => MFoldable (t a) where
    type Elem (t a) = a
    
    foldMap = Fold.foldMap
    foldr   = Fold.foldr
    foldr'  = Fold.foldr'
    foldr1  = Fold.foldr1
   
    foldl   = Fold.foldl
    foldl'  = Fold.foldl'
    foldl1  = Fold.foldl1

instance MFoldable B.ByteString where
    type Elem B.ByteString = Word8

    foldr  = B.foldr
    foldr' = B.foldr'
    foldr1 = B.foldr1   

    foldl  = B.foldl
    foldl' = B.foldl'
    foldl1 = B.foldl1

    mapM_  = bsMapM_gen

{-# SPECIALISE bsMapM_gen :: (Word8 -> IO a) -> B.ByteString -> IO ()     #-}
{-# SPECIALISE bsMapM_gen :: (Word8 -> ST s a) -> B.ByteString -> ST s () #-}

bsMapM_gen :: Monad m => (Word8 -> m a) -> B.ByteString -> m ()
bsMapM_gen f s = unsafePerformIO $ B.unsafeUseAsCStringLen s mapp
  where
    mapp (ptr, len) = return $ go 0
      where
        go i | i == len  = return ()
             | otherwise = let !b = B.inlinePerformIO $
                                    peekByteOff ptr i
                           in  f b >> go (i+1)


instance MFoldable T.Text where
    type Elem T.Text = Char

    foldr  = T.foldr
    foldr1 = T.foldr1   

    foldl  = T.foldl
    foldl' = T.foldl'
    foldl1 = T.foldl1

instance MFoldable (V.Vector a) where
    type Elem (V.Vector a) = a

    foldr  = V.foldr
    foldr' = V.foldr'
    foldr1 = V.foldr1   

    foldl  = V.foldl
    foldl' = V.foldl'
    foldl1 = V.foldl1

    foldM  = V.foldM
    mapM_  = V.mapM_

instance (Storable a) => MFoldable (VS.Vector a) where
    type Elem (VS.Vector a) = a

    foldr  = VS.foldr
    foldr' = VS.foldr'
    foldr1 = VS.foldr1   

    foldl  = VS.foldl
    foldl' = VS.foldl'
    foldl1 = VS.foldl1

    foldM  = VS.foldM
    mapM_  = VS.mapM_

instance (VU.Unbox a) => MFoldable (VU.Vector a) where
    type Elem (VU.Vector a) = a

    foldr  = VU.foldr
    foldr' = VU.foldr'
    foldr1 = VU.foldr1   

    foldl  = VU.foldl
    foldl' = VU.foldl'
    foldl1 = VU.foldl1

    foldM  = VU.foldM
    mapM_  = VU.mapM_
