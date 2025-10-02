import gleam
import gleam/erlang/process.{type Name, type Pid}
import gleam/io
import gleam/otp/actor
import gleam/otp/supervision
import glite/msg.{type CReqS, type CRespS}
import glydamic/child.{type Child, type StartError}

//import gleam/string

type State {
  State(trials: Int, my_subject: CRespS(String), client_subject: CReqS(String))
}

pub fn start(
  sup_name: Name(String),
  client_subject: CReqS(String),
) -> Result(Child, StartError) {
  case process.named(sup_name) {
    Ok(pid) -> {
      let child_spec =
        supervision.worker(fn() { start_link(client_subject) })
        |> supervision.restart(supervision.Temporary)
      child.start(pid, child_spec)
    }
    Error(Nil) -> Error(child.NoSupervisor)
  }
}

pub fn start_link(client_subject: CReqS(String)) {
  //  let assert Ok(actor.Started(pid, _subject1)) =
  actor.new_with_initialiser(100, fn(mysubject) {
    init(mysubject, client_subject)
  })
  |> actor.on_message(loop)
  |> actor.start()
  //  pid
}

fn init(
  mysubject: CRespS(String),
  client_subject: CReqS(String),
) -> Result(
  actor.Initialised(State, msg.ClientResponse(String), CRespS(String)),
  String,
) {
  let _ = child.set_label("glite_handler")

  // let self = string.inspect(process.self())
  // io.println("handler init: " <> self)
  // echo client_subject
  let selector =
    process.new_selector()
    |> process.select(mysubject)

  let state = State(0, mysubject, client_subject)

  let initialised =
    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(mysubject)

  process.send_after(
    client_subject,
    100,
    msg.CReq(mysubject, "Give me authentication string."),
  )
  Ok(initialised)
}

fn loop(
  state: State,
  msg: msg.ClientResponse(String),
) -> actor.Next(State, msg.ClientResponse(String)) {
  case msg {
    msg.CResp("die") -> panic as "Client is bad and kills the handler"
    msg.CResp("mysecretpin") -> {
      io.println("Client authenticated ok.")
      actor.send(
        state.client_subject,
        msg.CReq(state.my_subject, "You authenticated correct!"),
      )
      actor.stop()
    }
    _ if state.trials < 3 -> {
      actor.send(
        state.client_subject,
        msg.CReq(state.my_subject, "Wrong password try again."),
      )
      actor.continue(State(..state, trials: state.trials + 1))
    }
    msg.CResp(_x) -> {
      actor.send(
        state.client_subject,
        msg.CReq(state.my_subject, "Client tried too many times."),
      )
      actor.stop()
    }
  }
}
