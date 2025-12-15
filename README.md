# glite
_The Gleamlins little intro to Erlang applications_

The Erlang documentation for applications states:
>After creating code to implement a specific functionality, you might consider transforming it into an application — a component that can be started and stopped as a unit, as well as reused in other systems. [<sup>1</sup>](#ref)

So how does one turn a Gleam project into an Erlang application? Well many things are already in place actually. The `gleam build`command already creates a `<project>.app`file in the in the build ebin directory (e.g. ```build/dev/erlang/glite/ebin/glite.app```), and that is what the Erlang application controller basically needs.

An Erlang application may come in two "flavours", one as a plain library like `stdlib` which does not need to start any processes, and one where the application controller starts a service with several processes under a supervision tree. For the second case the controller checks the `<project>.app` file for the `mod` property which may look like:

__build/dev/erlang/glite/ebin/glite.app__
```erlang
{mod, {'glite_app', []}}
```
where the second tuple contains the start module and any start arguments.

## Configuration
When `gleam run` is executed it actually starts all registered applications (those having the `mod` property set). In order to enable it in our application we need to append to the `gleam.toml` file [<sup>2</sup>](#ref):

__gleam.toml__
```toml
[erlang]
application_start_module = "glite_app"
```
**This will add the mod property to the `glite.app` file.**

## Callback functions
In the start module the application controller expects two callback functions, `start/2` and `stop/1`, to be implemented.
Since Gleam compiles to Erlang source there is no problem to implement those in a Gleam module, `src/glite_app.gleam` in this case:

```rust
// --------------------- Erlang/OTP Application part --------------------
/// The Erlang/OTP application start callback.
/// Responsible to start the "top" supervisor process and return its Pid
/// to the application controller.
pub fn start(_app: Atom, _type) -> Result(process.Pid, actor.StartError) {
  io.println("Application start - starts the top supervisor")
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
...
}
```

<!--
 [![Package Version](https://img.shields.io/hexpm/v/glite)](https://hex.pm/packages/glite)
 [![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glite/)

```sh
gleam add glite@1
```
```gleam
import gliteapp

pub fn main() -> Nil {
  // TODO: An example of the project in use
}
```
-->
<!-- 
Further documentation can be found at <https://hexdocs.pm/glite>.
-->

## Joining the ecosystem
The benefits of doing all this is not obvious, but joining as a complete Erlang application gives the possibility to use diagnostic tools like `observer`to introspect your processes and trace messages.
> [!NOTE]
> The both the `main` function and the `start` function will be called when doing `gleam run` but only `start` if you start from an erlang shell. (`gleam shell` and then `application:ensure_all_started(glite)` for instance).
```rust
pub fn main() {
  io.println("Hello from gliteapp!")
  observer_start()
  process.sleep_forever()
}

type ErlangResult

@external(erlang, "observer", "start")
fn observer_start() -> ErlangResult
```
This will bring up the observer GUI. ![](doc/observer4.png)
You can also use the `sys` functions from the Erlang shell.
```
$ gleam shell

  Compiled in 0.07s
   Running Erlang shell
Erlang/OTP 28 [erts-16.0] [source] [64-bit] [smp:8:4] [ds:8:4:10] [async-threads:1] [jit:ns]

Eshell V16.0 (press Ctrl+G to abort, type help(). for help)
1> application:ensure_all_started(glite).
Application start - starts the top supervisor
{ok,[gleam_stdlib,gleam_erlang,gleam_otp,gleeunit,glite]}


7> i().
Pid                   Initial Call                          Heap     Reds Msgs
Registered            Current Function                     Stack              
..
<0.87.0>              application_master:init/3              233      260    0
                      application_master:main_loop/2           6              
<0.88.0>              application_master:start_it/4          233      594    0
                      application_master:loop_it/4             6              
<0.89.0>              supervisor:gleam@otp@static_super       73      301    0
                      gen_server:loop_hibernate/4              8              
..

8> sys:get_state(<0.89.0>).
{state,{<0.89.0>,gleam@otp@static_supervisor},
       rest_for_one,
       {[],#{}},
       undefined,2,5,[],0,0,never,1000,
       #Ref<0.4240582723.2716598273.224777>,
       gleam@otp@static_supervisor,
       {#{intensity => 2,period => 5,strategy => rest_for_one,
          auto_shutdown => never},
        []}}
9> 

```


```sh
gleam run   # Run the project
```

## Starting observer on another node

Generally one should be careful to run observer on a "production" server since it may load the VM and also involves wx (graphics) code which may not be present on an erlang backend system.

If the erlang VM is started in distributed mode one can start the observer on a remote node and connect to the running system.

A simple example for glite is to start two nodes on the same machine.
In one shell:
```shell
cd build/dev/erlang/
erl -sname backend -pa ./*/ebin
(backend@mymachine)1> application:ensure_all_started(glite).
src/glite_app.gleam:36
"Application start - starts the top supervisor"
{ok,[gleam_stdlib,gleam_erlang,gleam_otp,gleeunit,glite]}
Starting handler //erl(<0.102.0>)
Starting handler //erl(<0.103.0>)
Starting handler //erl(<0.104.0>)
..
```
In another shell:
```shell
erl -sname observe
(observe@mymachine)1> observer:start().
```
In observer there is a `Nodes` tab and under it one may select `backend@mymachine` to connect and display the applications/processes under that node.
When starting the nodes on different machines you should make sure to set the same _magic cookie_ on both nodes using flag `-setcookie Cookie` or any other way [<sup>3</sup>](#ref). You may also have to "manually" connect to the other node using the `Connect Node` tab in observer.

> [!NOTE]
> There is an alternative implementation to observer in Gleam - Spectator [<sup>4</sup>](#ref) with an [example](https://github.com/JonasGruenwald/spectator/tree/main/example) of inspecting an application running with Docker.

## <span id="ref">References</span>
[1]: [Applications](https://www.erlang.org/doc/system/applications.html) - Erlang documentation.<br/>
[2]: [gleam.toml](https://gleam.run/writing-gleam/gleam-toml/)<br/>
[3]: [Distributed Erlang](https://www.erlang.org/docs/28/system/distributed.html)<br/>
[4]: [Spectator](https://hexdocs.pm/spectator/)
