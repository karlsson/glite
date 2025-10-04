import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import glite
import glite/msg.{type CReqS, type CRespS}

type State {
  State(trials: Int, my_subject: CRespS(String), client_subject: CReqS(String))
}

pub fn start_link(client_subject: CReqS(String)) {
  actor.new_with_initialiser(100, fn(mysubject) {
    init(mysubject, client_subject)
  })
  |> actor.on_message(loop)
  |> actor.start()
}

fn init(
  mysubject: CRespS(String),
  client_subject: CReqS(String),
) -> Result(
  actor.Initialised(State, msg.ClientResponse(String), CRespS(String)),
  String,
) {
  let _ = glite.set_label("glite_handler")
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
