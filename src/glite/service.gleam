import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/string
import glite/handler
import glite/msg.{type SReqS}

// import glydamic/child
import gleam/otp/factory_supervisor as fsup

pub type SupName(c) =
  process.Name(fsup.Message(process.Subject(msg.ClientRequest(String)), c))

type State(c) {
  State(sup_name: SupName(c), my_subject: SReqS(String), no_reqs: Int)
}

pub fn start_link(
  sup_name: SupName(c),
  name: process.Name(msg.ServiceRequest(String)),
) -> process.Pid {
  let servsub = process.named_subject(name)
  let initialiser = fn(_subject: SReqS(String)) {
    let selector = process.new_selector() |> process.select(servsub)
    let state = State(sup_name: sup_name, my_subject: servsub, no_reqs: 0)
    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(servsub)
  }

  let assert Ok(actor.Started(pid, _data)) =
    actor.new_with_initialiser(1000, fn(subject) { Ok(initialiser(subject)) })
    |> actor.on_message(loop)
    |> actor.start()

  let _ = process.register(pid, name)
  pid
}

fn loop(state: State(a), msg) {
  case msg, state.no_reqs {
    msg.SReq(sender_subject), x if x < 10 -> {
      case fsup.start_child(fsup.get_by_name(state.sup_name), sender_subject) {
        // Ok(child.SupervisedChild(pid, _id)) -> {
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
