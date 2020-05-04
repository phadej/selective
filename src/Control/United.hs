{-# LANGUAGE ConstraintKinds, MultiParamTypeClasses, FunctionalDependencies #-}
{-# LANGUAGE EmptyCase, LambdaCase, GADTs, RankNTypes, ScopedTypeVariables #-}
-----------------------------------------------------------------------------
-- |
-- Module     : Control.United
-- Copyright  : (c) Andrey Mokhov 2018-2020
-- License    : MIT (see the file LICENSE)
-- Maintainer : andrey.mokhov@gmail.com
-- Stability  : experimental
--
-- An experiment in expressing Functor, Applicative, Selective and Monad using
-- the United type class, which combines Match and Batch type classes into one.
-- The name reflects the fact that the methods @match@ and @batch@ form a united
-- monoid in the category of endofunctors.
-----------------------------------------------------------------------------
module Control.United where

import Prelude hiding (fmap, pure)

-- | A generalised sum type where @t@ stands for the type of constructor "tags".
-- Each tag has a type parameter @x@ which determines the type of the payload.
data Sigma t a where
    Sigma :: t x -> (x -> a) -> Sigma t a

-- | A data type defining no tags. Similar to 'Data.Void.Void' but parameterised.
data Zero a where

-- | A data type with a single tag. This data type is commonly known as @Refl@,
-- see "Data.Type.Equality".
data One a b where
    One :: One a a

-- | A data type with two tags 'A' and 'B' that allows us to encode the good old
-- 'Either' as 'Sigma' 'Two', where the tags 'A' and 'B' correspond to 'Left'
-- and 'Right', respectively. See 'eitherToSigma' and 'sigmaToEither' that
-- witness the isomorphism between 'Either' @a b@ and 'Sigma' @(@'Two'@ a b)@.
data Two a b c where
    A :: Two a b a
    B :: Two a b b

-- Interestingly, this matches the type Mono from this blog post:
-- https://elvishjerricco.github.io/2017/03/23/applicative-sorting.html
-- | A potentially uncountable collection of tags.
data Many a b c where
    Many :: a -> Many a b b

class United p q f | f -> p q where
    batch :: p t => ((forall x. t x -> x) -> a) -> (forall x. t x -> f x) -> f a
    match :: q t => f (Sigma t a) -> (forall x. t x -> f x) -> f a

-- | This is the unit of both 'batch' and 'match'.
pure :: (United p q f, p Zero) => a -> f a
pure a = batch (const a) (\(x :: Zero a) -> case x of {})

fmap :: (United p q f, p (One a)) => (a -> b) -> f a -> f b
fmap f x = batch (\lookup -> f (lookup One)) (\One -> x)

mult :: (United p q f, p (Two a b)) => f a -> f b -> f (a, b)
mult x y = batch (\lookup -> (lookup A, lookup B)) $ \case { A -> x; B -> y }

branch :: (United p q f, p (One (Either a b)), q (Two (a -> c) (b -> c))) => f (Either a b) -> f (a -> c) -> f (b -> c) -> f c
branch x f g = match (fmap toSigma x) $ \case
    A -> f
    B -> g
  where
    toSigma (Left  a) = Sigma A ($a)
    toSigma (Right b) = Sigma B ($b)

bind :: (United p q f, p (One a), q (Many a b)) => f a -> (a -> f b) -> f b
bind x f = match (fmap toSigma x) (\(Many x) -> f x)
  where
    toSigma a = Sigma (Many a) id
