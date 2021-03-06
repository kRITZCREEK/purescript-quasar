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

module Quasar.Mount.Module where

import Prelude

import Data.Argonaut (Json, decodeJson, jsonEmptyObject, (.?), (~>), (:=))
import Data.Bifunctor (lmap)
import Data.Either (Either)
import SqlSquared (SqlModule)
import SqlSquared as Sql
import Text.Parsing.Parser (ParseError(..))
import Text.Parsing.Parser.Pos (Position(..))

type Config =
  { "module" ∷ SqlModule
  }

toJSON ∷ Config → Json
toJSON config =
  "module" := Sql.printModule config."module" ~> jsonEmptyObject

fromJSON ∷ Json → Either String Config
fromJSON =
  decodeJson
    >=> (_ .? "module")
    >=> \str → do
      q ← Sql.parseModule str # lmap \(ParseError err (Position { line , column })) →
        "Expected valid query, but at line " <> show line <> "and column "
        <> show column <> " got parse error: \n" <> err
      pure { "module": q }
