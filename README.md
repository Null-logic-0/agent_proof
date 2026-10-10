# AgentProof

AgentProof helps a shop prove what an AI shopping agent was allowed to buy,
when a customer disputes a PayPal payment.

**▶ Watch the 2-minute demo:** [youtu.be/sGaf6BlRC3A](https://youtu.be/sGaf6BlRC3A)

## The problem

AI agents now buy things for people. Sometimes the customer later says
"I never allowed this purchase" and opens a dispute on PayPal. The shop then
has to prove that the agent was allowed to buy it.

AgentProof keeps that proof from the start, and turns it into evidence for
PayPal when a dispute arrives.

## Features

- **Give an agent a budget.** Set the agent's name, a spending limit, and what
  it may buy (for example "noise-cancelling headphones, up to $200").
- **Smart search box.** The AI reads what the agent may buy and fills in the
  search box (for example "laptop"). A small note shows who suggested it. In
  Demo Mode, a built-in demo version suggests it instead. You can always
  change it.
- **Let the agent shop.** The agent searches a small product catalog and picks
  a product. AgentProof checks the budget *before* paying. If the purchase is
  over the limit, it is blocked and PayPal is never called.
- **Pay with PayPal.** Each allowed purchase creates a PayPal order (PayPal
  Sandbox, or a built-in demo version).
- **Keep a full record.** Every step is saved: what the agent searched for,
  what it chose, the budget check, and the payment.
- **See the story of each purchase.** Every purchase has a case page with a
  timeline, from the customer's permission to the final answer to PayPal.
- **Handle a dispute.** On the case page you mark the order as delivered and
  open a customer dispute (both are simulated).
- **AI investigation.** AgentProof collects the facts and runs the checks with
  normal code: within budget, allowed before the purchase, delivered before
  the dispute, and more. Then an AI writes the evidence from those facts.
  Every amount and ID the AI writes is checked against the facts. If the
  answer is wrong, the AI is asked once more. Nothing unchecked is saved.
- **Review and approve.** The shop reads the AI's evidence next to the checks
  and approves it. Running the investigation again removes the approval.
- **Send to PayPal.** You see the exact request PayPal will receive, then
  submit it. After that, the case is locked and nothing can change.
- **Transaction history.** All purchases on one page, with page numbers.
  Search by product, agent, or PayPal order ID, filter by status, and sort by
  date, amount, or status.
- **Edit or delete agents.** You can change an agent's name, limit, and
  description. Old purchases keep the terms they were bought under. An agent
  with purchases cannot be deleted, so the evidence is never lost.
- **Demo Mode.** A switch in the top bar that makes the app use built-in demo
  versions of PayPal and the AI. One button builds a complete example case.
- **Safety net.** If PayPal or the AI is down, the app uses the demo version
  instead and clearly says so.
- **Works everywhere.** Light and dark theme, and it fits phone screens.

## How it works

```
Customer sets a budget → Agent shops → Budget check → PayPal payment
→ Delivery → Customer opens a dispute → Code collects facts and runs checks
→ AI writes the evidence → Shop approves → Evidence is sent to PayPal
```

The key idea: **code finds the facts, the AI only writes the words.** The
checks never come from the AI, and the AI's text is checked before it is
saved.

## Setup and run

There are two ways to run AgentProof. Docker is the easiest.

### Option 1: Docker (easiest)

**You need:** [Docker Desktop](https://www.docker.com/products/docker-desktop/).

1. Get the code and open its folder:

   ```bash
   git clone https://github.com/Null-logic-0/agent_proof.git
   cd agent_proof
   ```

2. Start the app. The first time takes a few minutes.

   ```bash
   docker compose up --build
   ```

3. Open [http://localhost:4000](http://localhost:4000).

The app starts with example data: **OfficeBot** with two purchases, and a
**DemoBot** case that is ready for review.

To stop the app, press `Ctrl+C`. To start again later, run
`docker compose up`. To delete all data and start fresh, run
`docker compose down -v`.

If port 4000 is already in use, stop the other app first.

### Option 2: On your computer (for development)

**You need:**

- Elixir 1.20 with Erlang/OTP 29
- PostgreSQL, running, with the user `postgres` and the password `postgres`

1. Get the code and open its folder (see step 1 above).

2. Install everything and create the database with example data:

   ```bash
   mix setup
   ```

3. Start the app:

   ```bash
   mix phx.server
   ```

4. Open [http://localhost:4000](http://localhost:4000).

### Optional: use a real AI (Ollama)

Without this, the app still works: it writes the evidence with its built-in
demo AI.

1. Install [Ollama](https://ollama.com) and open it.
2. Download the model:

   ```bash
   ollama pull llama3.2
   ```

3. Keep Ollama open while you use AgentProof. With Docker, the app finds
   Ollama on your computer by itself.

The first investigation takes longer (about 25 seconds) because Ollama loads
the model. After that, it takes about 10 to 15 seconds.

### Optional: use PayPal Sandbox

Without this, the app uses its built-in demo PayPal.

1. Go to [developer.paypal.com](https://developer.paypal.com), log in, and
   open **Apps & Credentials**. Choose **Sandbox** and create an app.
2. Copy the example settings file:

   ```bash
   cp .env.example .env
   ```

3. Open `.env`. Remove the `#` before `PAYPAL_CLIENT_ID` and
   `PAYPAL_SECRET_KEY`, and paste your two values.
4. Start the app:
   - **Docker:** run `docker compose up` as usual. It reads `.env` by itself.
   - **On your computer:** load `.env` first:

     ```bash
     set -a; source .env; set +a; mix phx.server
     ```

The `.env` file holds your secrets. It is ignored by Git and never copied into
the Docker image.

### All settings

| Setting | If not set | What it does |
|---|---|---|
| `PAYPAL_CLIENT_ID`, `PAYPAL_SECRET_KEY` | Demo PayPal | Your PayPal Sandbox app keys |
| `OLLAMA_URL` | `http://localhost:11434` | Where Ollama runs |
| `OLLAMA_MODEL` | `llama3.2` | Which Ollama model to use |
| `OPENAI_API_KEY` | OpenAI is off | Turns on OpenAI as an AI option |
| `OPENAI_MODEL` | `gpt-6-luna` | Which OpenAI model to use |
| `AI_PROVIDER` | Ollama | Set to `openai` to use OpenAI instead |

The top bar always shows which PayPal and AI are in use.

## Try it

1. On the dashboard, the **Authorize an agent** form is already filled in.
   Click **Authorize agent**.
2. On the new agent's card, the AI fills in the search box (`headphones`).
   First, replace it with `laptop` and click **Let the agent shop**.
   It is blocked: it costs more than the limit.
3. Type `headphones` and click **Let the agent shop**. This time it is bought.
4. Click the purchase to open its case page and see the timeline.
5. Click **Mark as delivered**, then **Dispute opened**.
6. Click **Run AI investigation** and wait a few seconds.
7. Read the evidence next to the checks. Click **Approve evidence**.
8. Click **Prepare PayPal submission**, look at the request, and click
   **Submit to PayPal**.

**Shortcut:** turn on **Demo Mode** in the top bar, then click
**Run the demo scenario** on the dashboard. It builds a full case in about
two seconds, ready for steps 7 and 8.

## Demo Mode and the safety net

- **Demo Mode** is a switch in the top bar. When it is on, purchases and AI
  investigations use the built-in demo versions, so nothing outside your
  computer is called. A banner shows on every page. It only affects your
  browser.
- **The safety net works even when Demo Mode is off.** If PayPal can't create
  an order, the demo PayPal takes the payment. If the AI fails, the demo AI
  writes the evidence. Both are saved and clearly marked (a warning in the
  timeline, and evidence labelled `demo-fallback`).
- **Sending evidence to PayPal never uses the safety net.** A real dispute is
  only marked as sent if PayPal really received it.

## What is real and what is simulated

| Real | Simulated (and marked in the app) |
|---|---|
| Saving every record in PostgreSQL | The shopping agent (it follows a script) |
| The budget check, safe even with two purchases at once | The product catalog (4 products) |
| The full record of the agent's steps | Taking the money (PayPal needs the buyer to approve in a browser) |
| The facts and checks for a dispute | The delivery |
| The AI's evidence (Ollama or OpenAI) and its checking | The dispute (shops can't create PayPal disputes) |
| Creating PayPal Sandbox orders | So, sending evidence for these disputes |
| The exact evidence request for PayPal | |

## Tests

```bash
mix test
```

The tests don't need PayPal, Ollama, or OpenAI: their calls are answered by
stand-ins. One test, `test/agent_proof_web/live/demo_flow_test.exs`, clicks
through the whole app from start to finish.

Before you commit, run `mix precommit`. It stops on any compiler warning,
removes unused packages from the lock file, formats the code, and runs the
tests.

## Built with

Elixir, Phoenix LiveView, PostgreSQL, Tailwind CSS with daisyUI, Ollama, and
Docker.

The code is split into parts that each do one job:

- **Authorizations:** agents and their budgets
- **Transactions:** purchases, the budget check, and the timeline
- **Disputes:** customer disputes
- **Evidence:** the AI investigation, approval, and sending to PayPal
- **PayPal** and **AI:** the outside services, each with a demo version

## License

AgentProof is released under the [MIT License](LICENSE).
