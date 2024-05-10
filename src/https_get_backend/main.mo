import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Types "Types";

actor {
    // Transfrom the raw content into an HTTP payload.
    public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpReponsePayload {
        let transformed : Types.CanisterHttpReponsePayload = {
            status = raw.response.status;
            body = raw.response.body;
            headers = [
                {
                    name = "Content-Security-Policy";
                    value = "default-src 'self'";
                },
                { name = "Referrer-Policy"; value = "strict-origin" },
                { name = "Permissions-Policy"; value = "geolocation=(self)" },
                {
                    name = "Strict-Transport-Security";
                    value = "max-age=63072000";
                },
                { name = "X-Frame-Options"; value = "DENY" },
                { name = "X-Content-Type-Options"; value = "nosniff" },
            ];
        };
        transformed;
    };

    // Send GET request
    public func get_icp_usd_exchange() : async Text {
        // declare management canister
        let ic : Types.IC = actor ("aaaaa-aa");

        let ONE_MINUTE : Nat64 = 60;
        let start_timestamp : Types.Timestamp = 1682978460; //May 1, 2023 22:01:00 GMT
        let end_timestamp : Types.Timestamp = 1682978520; //May 1, 2023 22:02:00 GMT
        let host : Text = "api.pro.coinbase.com";
        let url = "https://" # host # "/products/ICP-USD/candles?start=" # Nat64.toText(start_timestamp) # "&end=" # Nat64.toText(end_timestamp) # "&granularity=" # Nat64.toText(ONE_MINUTE);

        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "exchange_rate_canister" },
        ];

        // Next, you define a function to transform the request's context from a blob datatype to an array.
        let transform_context : Types.TransformContext = {
            function = transform;
            context = Blob.fromArray([]);
        };

        // define HTTP request
        let http_request : Types.HttpRequestArgs = {
            url = url;
            max_response_bytes = null; // optional for request
            headers = request_headers;
            body = null; // optional for request
            method = #get;
            transform = ?transform_context;
        };

        // Now, you need to add some cycles to your call, since cycles to pay for the call must be transferred with the call.
        // The way Cycles.add() works is that it adds those cycles to the next asynchronous call.
        // "Function add(amount) indicates the additional amount of cycles to be transferred in the next remote call".
        // See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request

        Cycles.add(20_949_972_000);


        // Now that you have the HTTP request and cycles to send with the call, you can make the HTTP request and await the response.
        let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

        // Once you have the response, you need to decode it. The body of the HTTP response should come back as [Nat8], which needs to be decoded into readable text.
        // To do this, you:
        //  1. Convert the [Nat8] into a Blob
        //  2. Use Blob.decodeUtf8() method to convert the Blob to a ?Text optional
        //  3. Use a switch to explicitly call out both cases of decoding the Blob into ?Text

        let response_body : Blob = Blob.fromArray(http_response.body);
        let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
            case (null) { "No value returned" };
            case (?y) { y };
        };

        // Finally, you can return the response of the body.

        // The API response will looks like this:

        // ("[[1682978460,5.714,5.718,5.714,5.714,243.5678]]")

        // Which can be formatted as this
        //  [
        //     [
        //         1682978460, <-- start/timestamp
        //         5.714, <-- low
        //         5.718, <-- high
        //         5.714, <-- open
        //         5.714, <-- close
        //         243.5678 <-- volume
        //     ],
        // ]

        decoded_text

    };

};
