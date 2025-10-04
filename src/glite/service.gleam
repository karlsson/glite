import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/otp/factory_supervisor as fsup
import gleam/string
import glite/msg.{type SReqS}

pub type SupName(c) =
  process.Name(fsup.Message(process.Subject(msg.ClientRequest(String)), c))

type State(c) {
  State(sup_name: SupName(c), no_reqs: Int)
}

pub fn start_link(
  sup_name: SupName(c),
  name: process.Name(msg.ServiceRequest(String)),
) -> actor.StartResult(SReqS(String)) {
  actor.new(State(sup_name, no_reqs: 0))
  |> actor.named(name)
  |> actor.on_message(loop)
  |> actor.start
}

fn loop(state: State(a), msg) {
  case msg, state.no_reqs {
    msg.SReq(sender_subject), x if x < 10 -> {
      case fsup.start_child(fsup.get_by_name(state.sup_name), sender_subject) {
        Ok(actor.Started(pid, _)) -> {
          let reply = "Starting handler " <> string.inspect(pid)
          io.println(reply)
        }
        Error(e) -> {
          let reply = "Supervisor could not start handler" <> string.inspect(e)
          panic as reply
        }
      }
    }
    _, _ -> panic as "Service panic due to reqs > 9 - restarting"
  }
  actor.continue(State(..state, no_reqs: state.no_reqs + 1))
}
