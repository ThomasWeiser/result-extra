module Result.Extra exposing
    ( isOk, isErr, extract, unwrap, unpack, error, mapBoth, merge, join, partition, filter, transpose
    , combine, combineMap, combineFirst, combineSecond, combineBoth, combineMapFirst, combineMapSecond, combineMapBoth
    , singleton, andMap
    , or, orLazy, orElseLazy, orElse
    , toTask
    )

{-| Convenience functions for working with `Result`.


# Common Helpers

@docs isOk, isErr, extract, unwrap, unpack, error, mapBoth, merge, join, partition, filter, transpose


# Combining

@docs combine, combineMap, combineFirst, combineSecond, combineBoth, combineMapFirst, combineMapSecond, combineMapBoth


# Applying

@docs singleton, andMap


# Alternatives

@docs or, orLazy, orElseLazy, orElse


# Conversions

@docs toTask

-}

import Task exposing (Task)


{-| Check whether the result is `Ok` without unwrapping it.
-}
isOk : Result e a -> Bool
isOk x =
    case x of
        Ok _ ->
            True

        Err _ ->
            False


{-| Check whether the result is `Err` without unwrapping it.
-}
isErr : Result e a -> Bool
isErr x =
    case x of
        Ok _ ->
            False

        Err _ ->
            True


{-| Turn a `Result e a` to an `a`, by applying the conversion
function specified to the `e`.
-}
extract : (e -> a) -> Result e a -> a
extract f x =
    case x of
        Ok a ->
            a

        Err e ->
            f e


{-| Convert a `Result e a` to a `b` by applying a function if
the `Result` is `Ok` or using the provided default value if it
is an `Err`.
-}
unwrap : b -> (a -> b) -> Result e a -> b
unwrap defaultValue okFunc result =
    case result of
        Ok ok ->
            okFunc ok

        Err _ ->
            defaultValue


{-| Convert a `Result e a` to a `b` by applying either the first
function if the `Result` is an `Err` or the second function if the
`Result` is `Ok`. Both of these functions must return the same type.
-}
unpack : (e -> b) -> (a -> b) -> Result e a -> b
unpack errFunc okFunc result =
    case result of
        Ok ok ->
            okFunc ok

        Err err ->
            errFunc err


{-| Convert to a Maybe containing the error, if there is one.

    parseInt : String -> Result ParseError Int

    maybeParseError : String -> Maybe ParseError
    maybeParseError string =
        error (parseInt string)

-}
error : Result e a -> Maybe e
error result =
    case result of
        Ok _ ->
            Nothing

        Err err ->
            Just err


{-| Apply the first argument function to an `Err` and the second
argument function to an `Ok` of a `Result`.
-}
mapBoth : (e -> f) -> (a -> b) -> Result e a -> Result f b
mapBoth errFunc okFunc result =
    case result of
        Ok ok ->
            Ok <| okFunc ok

        Err err ->
            Err <| errFunc err



-- Combining


{-| Combine a list of results into a single result (holding a list).
Also known as `sequence` on lists.
-}
combine : List (Result x a) -> Result x (List a)
combine =
    List.foldr (Result.map2 (::)) (Ok [])


{-| Map a function producing results on a list
and combine those into a single result (holding a list).
Also known as `traverse` on lists.

    combineMap f xs == combine (List.map f xs)

-}
combineMap : (a -> Result x b) -> List a -> Result x (List b)
combineMap f =
    combine << List.map f


{-| Pull a result out of the _first_ element of a tuple
and combine it into a result holding the tuple's values.
-}
combineFirst : ( Result x a, c ) -> Result x ( a, c )
combineFirst ( rx, y ) =
    Result.map (\x -> Tuple.pair x y) rx


{-| Pull a result out of the _second_ element of a tuple
and combine it into a result holding the tuple's values.
Also known as `sequence` on tuples.
-}
combineSecond : ( c, Result x a ) -> Result x ( c, a )
combineSecond ( x, ry ) =
    Result.map (Tuple.pair x) ry


{-| Combine all results in a tuple
into a single result holding the tuple's values.
Also know as `bisequence` on tuples.
-}
combineBoth : ( Result x a, Result x b ) -> Result x ( a, b )
combineBoth ( rx, ry ) =
    Result.map2 Tuple.pair rx ry


{-| Map a function producing results on the _first_ element of a tuple
and then pull it out using `combineFirst`.
Also know as `sequence` on tuples.

    combineMapFirst f ( x, y )
        == combineFirst (Tuple.mapFirst f ( x, y ))
        == Result.map (flip Tuple.pair y) (f x)

-}
combineMapFirst : (a -> Result x b) -> ( a, c ) -> Result x ( b, c )
combineMapFirst f =
    combineFirst << Tuple.mapFirst f


{-| Map a function producing results on the _second_ element of a tuple
and then pull it out using `combineSecond`.
Also know as `traverse` on tuples.

    combineMapSecond f ( x, y )
        == combineSecond (Tuple.mapSecond f ( x, y ))
        == Result.map (Tuple.pair x) (f y)

-}
combineMapSecond : (a -> Result x b) -> ( c, a ) -> Result x ( c, b )
combineMapSecond f =
    combineSecond << Tuple.mapSecond f


{-| Map a function producing results on the _both_ elements of a tuple
and then pull them out using `combineBoth`.
Also know as `bitraverse` on tuples.

    combineMapBoth f g ( x, y )
        == combineBoth (Tuple.mapBoth f g ( x, y ))
        == Result.map2 Tuple.pair (f x) (g y)

-}
combineMapBoth : (a -> Result x c) -> (b -> Result x d) -> ( a, b ) -> Result x ( c, d )
combineMapBoth f g =
    combineBoth << Tuple.mapBoth f g



-- Applying


{-| Create a `singleton` from a value to an `Result` with a `Ok`
of the same type. Also known as `pure`. You can use the `Err`
constructor for a singleton of the `Err` variety.

    singleton 2 == Ok 2

-}
singleton : a -> Result e a
singleton =
    Ok


{-| Apply the function that is inside `Result` to a value that is inside
`Result`. Return the result inside `Result`. If one of the `Result`
arguments is `Err e`, return `Err e`. Also known as `apply`.

    Err "Oh" |> andMap (Err "No!") == Err "Oh"

    Err "Oh" |> andMap (Ok 2) == Err "Oh"

    Ok ((+) 1) |> andMap (Err "No!") == Err "No!"

    Ok ((+) 1) |> andMap (Ok 2) == Ok 3

-}
andMap : Result e a -> Result e (a -> b) -> Result e b
andMap ra rb =
    case ( ra, rb ) of
        ( _, Err x ) ->
            Err x

        ( o, Ok fn ) ->
            Result.map fn o



-- Alternatives


{-| Like the Boolean `||` this will return the first value that is
positive (`Ok`). However, unlike with `||`, both values will be
computed anyway (there is no short-circuiting).

    or (Ok 4) (Ok 5) == Ok 4

    or (Err "Oh!") (Ok 5) == Ok 5

    or (Ok 4) (Err "No!") == Ok 4

    or (Err "Oh!") (Err "No!") == Err "No!"

As the last example line shows, the second error is returned if both
results are erroneous.

-}
or : Result e a -> Result e a -> Result e a
or ra rb =
    case ra of
        Err _ ->
            rb

        Ok _ ->
            ra


{-| Non-strict version of `or`. The second argument will only be
evaluated if the first argument is an `Err`.
-}
orLazy : Result e a -> (() -> Result e a) -> Result e a
orLazy ra frb =
    case ra of
        Err _ ->
            frb ()

        Ok _ ->
            ra


{-| Piping-friendly version of `orLazy`. The first argument will only
be evaluated if the second argument is an `Err`. Example use:

    String.toInt "Hello"
        |> orElseLazy (\() -> String.toInt "42")

-}
orElseLazy : (() -> Result e a) -> Result e a -> Result e a
orElseLazy fra rb =
    orLazy rb fra


{-| Strict version of `orElseLazy` (and at the same time,
piping-friendly version of `or`).

    orElse (Ok 4) (Ok 5) == Ok 5 -- crucial difference from `or`

    orElse (Err "Oh!") (Ok 5) == Ok 5

    orElse (Ok 4) (Err "No!") == Ok 4

    orElse (Err "Oh!") (Err "No!") == Err "Oh!" -- also different from `or`

Also:

    String.toInt "Hello"
        |> orElse (String.toInt "42")

-}
orElse : Result e a -> Result e a -> Result e a
orElse ra rb =
    or rb ra



-- OTHER --


{-| Eliminate Result when error and success have been mapped to the same
type, such as a message type.

    merge (Ok 4) == 4

    merge (Err -1) == -1

More pragmatically:

    type Msg
        = UserTypedInt Int
        | UserInputError String

    msgFromInput : String -> Msg
    msgFromInput =
        String.toInt
            >> Result.mapError UserInputError
            >> Result.map UserTypedInt
            >> Result.Extra.merge

-}
merge : Result a a -> a
merge r =
    case r of
        Ok rr ->
            rr

        Err rr ->
            rr


{-| Join contained results with the same error into one result.

Usefull if you have a "result in a result":

    join <| Ok (Ok 4) == Ok 4

    join <| Ok (Err "message") == Err "message"

-}
join : Result x (Result x a) -> Result x a
join r =
    case r of
        Err x ->
            Err x

        Ok (Err x) ->
            Err x

        Ok (Ok a) ->
            Ok a


{-| Partition a list of Results into two lists of values (successes
and failures), much as List.partition takes a predicate and splits
a list based on whether the predicate indicates success or failure.

    partition ( Ok 4, Err "no", Err "hi" ) == ( [ 4 ], [ "no", "hi" ] )

    partition ( Err 7.1, Ok 'k', Err 9.0, Ok 'p' ) == ( [ 'k', 'p' ], [ 7.1, 9.0 ] )

-}
partition : List (Result e a) -> ( List a, List e )
partition rs =
    List.foldr
        (\r ( succ, err ) ->
            case r of
                Ok v ->
                    ( v :: succ, err )

                Err v ->
                    ( succ, v :: err )
        )
        ( [], [] )
        rs


{-| Take a `Result` and a predicate function and return a `Result` with the
original value when a predicate matches.

    filter "is not 1" (\v -> v == 1) (Ok 1) == Ok 1

    filter "is not 2" (\v -> v == 2) (Ok 1) == Err "is not 2"

-}
filter : e -> (a -> Bool) -> Result e a -> Result e a
filter err predicate result =
    case Result.map predicate result of
        Ok True ->
            result

        Ok False ->
            Err err

        Err _ ->
            result


{-| Pull out a Result from a Maybe.

    transpose Nothing =
        Ok Nothing
    transpose (Just (Ok "value")) =
        Ok (Just "value")
    transpose (Just (Err "error")) =
        Err "error"

-}
transpose : Maybe (Result e a) -> Result e (Maybe a)
transpose maybeOfResult =
    case maybeOfResult of
        Nothing ->
            Ok Nothing

        Just (Err err) ->
            Err err

        Just (Ok value) ->
            Ok (Just value)



-- Conversions


{-| Convert a `Result` to a `Task` that will fail or succeed immediately.

    toTask (Ok 4) == Task.succeed 4

    toTask (Err "msg") == Task.fail "msg"

This can be helpful when the value of a succeeding Task needs to be decoded, but
a failure to decode should result in a failing `Task`, not a succeeding Task
containing a `Result.Err`:

andThenDecode : (a -> Result x b) -> Task x a -> Task x b
andThenDecode decode =
Task.andThen (decode >> Result.Extra.toTask)

-}
toTask : Result x a -> Task x a
toTask result =
    case result of
        Ok a ->
            Task.succeed a

        Err x ->
            Task.fail x
