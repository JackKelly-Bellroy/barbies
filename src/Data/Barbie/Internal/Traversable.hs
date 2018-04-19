-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Barbie.Internal.Functor
----------------------------------------------------------------------------
{-# LANGUAGE DefaultSignatures  #-}
{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE FlexibleInstances  #-}
{-# LANGUAGE LambdaCase         #-}
{-# LANGUAGE Rank2Types         #-}
{-# LANGUAGE TypeApplications   #-}
{-# LANGUAGE TypeFamilies       #-}
{-# LANGUAGE TypeOperators      #-}
module Data.Barbie.Internal.Traversable
  ( TraversableB(..)
  , bsequence

  , GTraversableB
  , gbtraverseDefault
  )

where

import Data.Barbie.Internal.Functor (FunctorB(..))
import Data.Barbie.Internal.Generics
import Data.Functor.Compose (Compose(..))
import GHC.Generics


-- | Barbie-types that can be traversed fro left to right. Instances should
--   satisfy the following laws:
--
-- @
--  t . 'btraverse' f = 'btraverse' (t . f)  -- naturality
-- 'btraverse' 'Data.Functor.Identity' = 'Data.Functor.Identity'         -- identity
-- 'btraverse' ('Compose' . 'fmap' g . f) = 'Compose' . 'fmap' ('btraverse' g) . 'btraverse' f -- composition
-- @
--
-- There is a default 'btraverse' implementation for 'Generic' types, so
-- instances can derived automatically.
class FunctorB b => TraversableB b where
  btraverse :: Applicative t => (forall a . f a -> t (g a)) -> b f -> t (b g)

  default btraverse
    :: ( Applicative t
       , Generic (b (Target F))
       , Generic (b (Target G))
       , GTraversableB (Rep (b (Target F)))
       , Rep (b (Target G)) ~ Repl (Target F) (Target G) (Rep (b (Target F)))
       )
    => (forall a . f a -> t (g a))
    -> b f -> t (b g)
  btraverse = gbtraverseDefault



-- | Evaluate each action in the structure from left to right,
--   and collect the results.
bsequence :: (Applicative f, TraversableB b) => b (Compose f g) -> f (b g)
bsequence
  = btraverse getCompose


-- | Default implementation of 'btraverse' based on 'Generic'.
gbtraverseDefault
  :: ( Applicative t
     , Generic (b (Target F))
     , Generic (b (Target G))
     , GTraversableB (Rep (b (Target F)))
     , Rep (b (Target G)) ~ Repl (Target F) (Target G) (Rep (b (Target F)))
     )
  => (forall a . f a -> t (g a))
  -> b f -> t (b g)
gbtraverseDefault f b
  = unsafeUntargetBarbie @G . to <$> gbtraverse f (from (unsafeTargetBarbie @F b))



class GTraversableB b where
  gbtraverse
    :: Applicative t
    => (forall a . f a -> t (g a))
    -> b x -> t (Repl (Target F) (Target G) b x)

data F a
data G a

-- ----------------------------------
-- Trivial cases
-- ----------------------------------

instance GTraversableB x => GTraversableB (M1 i c x) where
  {-# INLINE gbtraverse #-}
  gbtraverse f (M1 x) = M1 <$> gbtraverse f x

instance GTraversableB V1 where
  {-# INLINE gbtraverse #-}
  gbtraverse _ _ = undefined

instance GTraversableB U1 where
  {-# INLINE gbtraverse #-}
  gbtraverse _ u1 = pure u1

instance (GTraversableB l, GTraversableB r) => GTraversableB (l :*: r) where
  {-# INLINE gbtraverse #-}
  gbtraverse f (l :*: r)
    = (:*:) <$> gbtraverse f l <*> gbtraverse f r

instance (GTraversableB l, GTraversableB r) => GTraversableB (l :+: r) where
  {-# INLINE gbtraverse #-}
  gbtraverse f = \case
    L1 l -> L1 <$> gbtraverse f l
    R1 r -> R1 <$> gbtraverse f r


-- --------------------------------
-- The interesting cases
-- --------------------------------

instance {-# OVERLAPPING #-} GTraversableB (K1 R (Target F a)) where
  {-# INLINE gbtraverse #-}
  gbtraverse f (K1 fa)
    = K1 . unsafeTarget @G <$> f (unsafeUntarget @F fa)

instance (K1 i c) ~ Repl (Target F) (Target G) (K1 i c) => GTraversableB (K1 i c) where
  {-# INLINE gbtraverse #-}
  gbtraverse _ k1 = pure k1