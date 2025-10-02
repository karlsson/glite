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

/// Gleam run makes sure that all registered applications are started.
/// Check gleam.toml to see the start module in the [erlang] section:
///
/// application_start_module = "gleam@otp@application"
/// application_start_argument = "\<thismodule>\"
/// which in this case is `glite_app`.
pub fn main() {
  echo "Hello from glite_app main()"
  // application.new(fn(_start_type) { start_supervisor() })
}

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
  // let sub_sup_name = process.new_name("one_for_one_sup")
  let sub_sup_name: process.Name(
    fsup.Message(
      process.Subject(msg.ClientRequest(String)),
      process.Subject(msg.ClientResponse(String)),
    ),
  ) = process.new_name("factory_sup")
  let service_name = process.new_name("glite_service")
  let service_subject = process.named_subject(service_name)
  let service_child =
    supervision.worker(fn() {
      Ok(actor.Started(
        service.start_link(sub_sup_name, service_name),
        service_subject,
      ))
    })
  let client_child =
    supervision.worker(fn() {
      Ok(actor.Started(client.start_link(service_subject), Nil))
    })

  // let sup_sup =
  //   supervision.supervisor(fn() {
  //     let assert Ok(actor.Started(pid, data)) =
  //       sup.new(sup.OneForOne) |> sup.start
  //     case process.register(pid, sub_sup_name) {
  //       Ok(Nil) -> Ok(actor.Started(pid, data))
  //       Error(Nil) -> Error(actor.InitFailed("Supervisor name already exist"))
  //     }
  //   })

  let sup_sup =
    fsup.worker_child(handler.start_link)
    |> fsup.named(sub_sup_name)
    |> fsup.supervised

  sup.new(sup.OneForAll)
  |> sup.add(sup_sup)
  |> sup.add(service_child)
  |> sup.add(client_child)
  |> sup.add(client_child)
  |> sup.add(client_child)
  |> sup.start
}
