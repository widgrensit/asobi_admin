-module(asobi_admin_login_controller_tests).

-include_lib("eunit/include/eunit.hrl").

%% sanitize_redirect/1 is the open-redirect + header-injection guard for
%% `return_to`. Only same-origin paths under /admin/ui are ever followed.
sanitize_redirect_test_() ->
    [
        ?_assertEqual(
            ~"/admin/ui/players", asobi_admin_login_controller:sanitize_redirect(~"/admin/ui/players")
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard", asobi_admin_login_controller:sanitize_redirect(undefined)
        ),
        ?_assertEqual(~"/admin/ui/dashboard", asobi_admin_login_controller:sanitize_redirect(~"")),
        ?_assertEqual(
            ~"/admin/ui/dashboard", asobi_admin_login_controller:sanitize_redirect(~"/dashboard")
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard",
            asobi_admin_login_controller:sanitize_redirect(~"//evil.example.com")
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard",
            asobi_admin_login_controller:sanitize_redirect(~"https://evil.example.com")
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard",
            asobi_admin_login_controller:sanitize_redirect(~"/admin/ui/players\r\nSet-Cookie: x=y")
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard",
            asobi_admin_login_controller:sanitize_redirect(<<"/admin/ui/x", 0, "y">>)
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard",
            asobi_admin_login_controller:sanitize_redirect(~"/admin/ui/../../etc/passwd")
        ),
        ?_assertEqual(
            ~"/admin/ui/dashboard",
            asobi_admin_login_controller:sanitize_redirect(<<"/admin/ui/x", 226, 128, 168, "y">>)
        ),
        ?_assertEqual(
            ~"/admin/ui/players?limit=10&offset=20",
            asobi_admin_login_controller:sanitize_redirect(~"/admin/ui/players?limit=10&offset=20")
        )
    ].
