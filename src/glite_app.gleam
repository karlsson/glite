//// Supervisor starts one service, three client processes and also a
//// factory supervisor.
////
//// Clients send two requests each to service with subjects for receiving
//// request from "handlers"
////
//// The service process requests the factory supervisor to start
//// handler processes and passes on the service handler req subject.
////
//// The handlers sends req to clients and includes a response subject.
//// Client responds with (authentication) string which is wrong.
//// Counter is increased and handler reqest new authentication string.
//// When the counter exceeds 3 handler responds with error string and terminates.
////
//// If the service process receives more than 9 requests to start handlers it
//// will exit (panic). Just a hardcoded limit to test the one_for_all restart.

import gleam/erlang/atom.{type Atom}
import gleam/erlang/process
import gleam/otp/actor

// import gleam/otp/application
import gleam/otp/factory_supervisor as fsup
import gleam/otp/static_supervisor as sup
import gleam/otp/supervision
import glite/client
import glite/handler
import glite/msg
import glite/service

// --------------------- Erlang/OTP Application part --------------------
/// The Erlang/OTP application start callback.
/// Responsible to start the "top" supervisor process and return its Pid
/// to the application controller.
pub fn start(_app: Atom, _type) -> Result(process.Pid, actor.StartError) {
  echo "Application start - starts the top supervisor"
  case start_supervisor() {
    Ok(actor.Started(pid, _data)) -> {
      let sup_name = process.new_name("one_for_all_sup")
      let _ = process.register(pid, sup_name)
      Ok(pid)
    }
    Error(reason) -> Error(reason)
  }
}

/// The Erlang/OTP application stop callback.
/// This is called after all processes in the supervisor tree have
/// been shutdown by the application controller. Responsible for any
/// final clean up actions.
pub fn stop(_state: a) -> Atom {
  atom.create("ok")
}

// -------- Supervisor ----------------------------------
/// Erlang application top supervisor
fn start_supervisor() -> Result(actor.Started(sup.Supervisor), actor.StartError) {
  let sub_sup_name: process.Name(
    fsup.Message(
      process.Subject(msg.ClientRequest(String)),
      process.Subject(msg.ClientResponse(String)),
    ),
  ) = process.new_name("factory_sup")
  let service_name = process.new_name("glite_service")

  let service_child =
    supervision.worker(fn() { service.start_link(sub_sup_name, service_name) })

  let service_subject = process.named_subject(service_name)
  let client_child =
    supervision.worker(fn() {
      Ok(actor.Started(client.start_link(service_subject), Nil))
    })

  let factory_supervisor =
    fsup.worker_child(handler.start_link)
    |> fsup.named(sub_sup_name)
    |> fsup.supervised

  sup.new(sup.OneForAll)
  |> sup.add(factory_supervisor)
  |> sup.add(service_child)
  |> sup.add(client_child)
  |> sup.add(client_child)
  |> sup.add(client_child)
  |> sup.start
}
