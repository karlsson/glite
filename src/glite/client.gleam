import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/string
import glite
import glite/msg

//import gleam/string

type State {
  State(my_subject: msg.CReqS(String), service_subject: msg.SReqS(String))
}

pub fn start_link(
  service_subject: msg.SReqS(String),
) -> actor.StartResult(msg.CReqS(String)) {
  actor.new_with_initialiser(100, fn(mysubject: msg.CReqS(String)) {
    init(mysubject, service_subject)
  })
  |> actor.on_message(loop)
  |> actor.start()
}

fn init(
  mysubject: msg.CReqS(String),
  service_subject: msg.SReqS(String),
) -> Result(
  actor.Initialised(State, msg.ClientRequest(String), msg.CReqS(String)),
  String,
) {
  let _ = glite.set_label("glite_client")
  let selector = process.new_selector() |> process.select(mysubject)
  let state = State(mysubject, service_subject)

  process.send_after(mysubject, 100, msg.SelfReq("initphase"))

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(mysubject)
  |> Ok
}

fn loop(
  state: State,
  msg: msg.ClientRequest(String),
) -> actor.Next(State, msg.ClientRequest(String)) {
  case msg {
    msg.SelfReq("initphase") -> {
      // Send request to service for two new handlers every 16 s
      process.send_after(state.my_subject, 16_000, msg.SelfReq("initphase"))
      process.send_after(
        state.service_subject,
        1000,
        msg.SReq(state.my_subject),
      )
      process.send(state.service_subject, msg.SReq(state.my_subject))
    }
    msg.CReq(handler_subject, request) -> {
      let a = process.subject_owner(handler_subject) |> string.inspect
      io.println(a <> ": " <> request)
      process.send_after(
        handler_subject,
        4000,
        msg.CResp("I am sending the wrong pin"),
      )
      Nil
    }
    _ -> Nil
  }
  actor.continue(state)
}
