//// Supervisor starts one service, three client processes and also a
//// one_for_one supervisor.
////
//// Clients send two requests each to service with subjects for receiving
//// request from "handlers"
////
//// The service process requests the "one_to_one" supervisor to start
//// handler processes and passes on the service handler req subject.
////
//// The handlers sends req to clients and includes a response subject.
//// Client responds with (authentication) string which is wrong.
//// Counter is increased and handler reqest new authentication string.
//// When the counter exceeds 3 handler responds with error string and terminates.
////
//// If the service process receives more than 9 requests to start handlers it
//// will exit (panic). Just a hardcoded limit to test the one_for_all restart.

import gleam/erlang/process

/// Gleam run makes sure that all registered applications are started,
/// so the main function will just sleep forever.
/// Check gleam.toml to see the start module in the [erlang] section:
///
/// application_start_module = "\<thismodule>\"
/// which in this case is `glite_app`.
pub fn main() {
  echo "Hello from glite main()"
  observer_start()
  process.sleep_forever()
}

type ErlangResult

@external(erlang, "observer", "start")
fn observer_start() -> ErlangResult
