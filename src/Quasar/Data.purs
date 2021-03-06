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

module Quasar.Data where

import Data.Either (Either, either)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..), snd)
import Network.HTTP.Affjax.Request (class Requestable, toRequest)
import Quasar.Data.CSV as CSV
import Quasar.Data.Json as Json

data QData = QData (Either Json.Options CSV.Options) String

instance requestableQData ∷ Requestable QData where
  toRequest (QData mode content) =
    Tuple
      (Just (either Json.toMediaType CSV.toMediaType mode))
      (snd (toRequest content))
