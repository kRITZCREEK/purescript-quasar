{-
Copyright 2017 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module Quasar.Mount.SparkHDFS
  ( Config
  , toJSON
  , fromJSON
  , toURI
  , fromURI
  , module Exports
  ) where

import Prelude

import Data.Argonaut (Json, (.?), (:=), (~>))
import Data.Argonaut as J
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.List as L
import Data.Maybe (Maybe(..), maybe)
import Data.StrMap as SM
import Data.Tuple (Tuple(..))
import Data.URI as URI
import Data.URI.AbsoluteURI as AbsoluteURI
import Data.URI.Path (printPath, parseURIPathAbs)
import Global (encodeURIComponent, decodeURIComponent)
import Quasar.Mount.Common (Host) as Exports
import Quasar.Mount.Common (Host, extractHost)
import Quasar.Types (DirPath)
import Text.Parsing.StringParser (runParser)

type Config =
  { sparkHost ∷ Host
  , hdfsHost ∷ Host
  , path ∷ DirPath
  , props ∷ SM.StrMap (Maybe String)
  }

toJSON ∷ Config → Json
toJSON config =
  let uri = AbsoluteURI.print (toURI config)
  in "spark-hdfs" := ("connectionUri" := uri ~> J.jsonEmptyObject) ~> J.jsonEmptyObject

fromJSON ∷ Json → Either String Config
fromJSON
  = fromURI
  <=< lmap show <<< AbsoluteURI.parse
  <=< (_ .? "connectionUri")
  <=< (_ .? "spark-hdfs")
  <=< J.decodeJson

toURI ∷ Config → URI.AbsoluteURI
toURI cfg = mkURI sparkURIScheme cfg.sparkHost (Just (URI.Query $ requiredProps <> optionalProps))
  where
  requiredProps ∷ L.List (Tuple String (Maybe String))
  requiredProps = L.fromFoldable
    [ Tuple "hdfsUrl" $ Just $ encodeURIComponent $ AbsoluteURI.print $ mkURI hdfsURIScheme cfg.hdfsHost Nothing
    , Tuple "rootPath" $ Just $ printPath (Left cfg.path)
    ]

  optionalProps ∷ L.List (Tuple String (Maybe String))
  optionalProps = SM.toUnfoldable cfg.props

fromURI ∷ URI.AbsoluteURI → Either String Config
fromURI (URI.AbsoluteURI scheme (URI.HierarchicalPart auth _) query) = do
  unless (scheme == Just sparkURIScheme) $ Left "Expected `spark` URL scheme"
  sparkHost ← extractHost auth
  let props = maybe SM.empty (\(URI.Query qs) → SM.fromFoldable qs) query

  Tuple hdfsHost props' ← case SM.pop "hdfsUrl" props of
    Just (Tuple (Just value) rest) → do
      value' ← extractHost' hdfsURIScheme $ decodeURIComponent value
      pure (Tuple value' rest)
    _ → Left "Expected `hdfsUrl` query parameter"

  Tuple path props'' ← case SM.pop "rootPath" props' of
    Just (Tuple (Just value) rest) → do
      value' ← lmap show $ runParser parseURIPathAbs value
      dirPath ← case value' of
        Left dp → pure dp
        Right _ → Left "Expected `rootPath` to be a directory path"
      pure (Tuple dirPath rest)
    _ → Left "Expected `rootPath` query parameter"

  pure { sparkHost, hdfsHost, path, props: props'' }

mkURI ∷ URI.Scheme → Host → Maybe URI.Query → URI.AbsoluteURI
mkURI scheme host params =
  URI.AbsoluteURI
    (Just scheme)
    (URI.HierarchicalPart (Just (URI.Authority Nothing (pure host))) Nothing)
    params

extractHost' ∷ URI.Scheme → String → Either String Host
extractHost' scheme@(URI.Scheme name) uri = do
  URI.AbsoluteURI scheme' (URI.HierarchicalPart auth _) _ ←
    lmap show $ AbsoluteURI.parse uri
  unless (scheme' == Just scheme) $ Left $ "Expected '" <> name <> "' URL scheme"
  extractHost auth

sparkURIScheme ∷ URI.Scheme
sparkURIScheme = URI.Scheme "spark"

hdfsURIScheme ∷ URI.Scheme
hdfsURIScheme = URI.Scheme "hdfs"
