-module(asobi_admin_static_controller).
-moduledoc ~"""
Serves the console UI's vendored static assets from priv/static.

Deliberately an exact-filename allowlist rather than a general path-based file
server: the UI ships a small, fixed set of assets, so there is no path to
sanitize - an unlisted request is just a 404, with no filesystem-traversal
surface to defend at all.
""".

-export([serve_css/1]).

-define(CSS_FILES, #{~"console.css" => ~"public, max-age=3600"}).

-spec serve_css(cowboy_req:req()) -> {status, integer()} | {status, integer(), map(), iodata()}.
serve_css(#{bindings := #{~"file" := File}}) ->
    case maps:get(File, ?CSS_FILES, undefined) of
        undefined -> {status, 404};
        CacheControl -> serve_file([~"css", File], CacheControl)
    end;
serve_css(_Req) ->
    {status, 404}.

-spec serve_file([binary()], binary()) ->
    {status, integer()} | {status, integer(), map(), iodata()}.
serve_file(PathParts, CacheControl) ->
    case code:priv_dir(asobi_admin) of
        {error, bad_name} ->
            {status, 404};
        PrivDir ->
            Parts = [binary_to_list(P) || P <- PathParts],
            FullPath = filename:join([PrivDir, "static", "assets" | Parts]),
            case file:read_file(FullPath) of
                {ok, Content} ->
                    Headers = #{
                        ~"content-type" => mime_type(FullPath),
                        ~"cache-control" => CacheControl
                    },
                    {status, 200, Headers, Content};
                {error, _} ->
                    {status, 404}
            end
    end.

-spec mime_type(file:filename_all()) -> binary().
mime_type(Path) ->
    case filename:extension(Path) of
        ".css" -> ~"text/css; charset=utf-8";
        _ -> ~"application/octet-stream"
    end.
