#### Multiagent Code is an agent-based toolsuite for Claude Code that enables massively parallelized AI coding agents with built-in reflexion, job management, and interpolated dynamic prompting.

### 1. Install the repo locally

```
git clone https://github.com/willsmanley/multiagent-code && chmod +x multiagent-code/install.sh && multiagent-code/install.sh
```

> _This clones the repo locally; then runs a script to give Claude Code access to job management shell scripts and orchestration prompts, and installs a Claude Command called `/orchestrator` ._

### 2. Start interactive Claude Code in Yolo Mode

```
claude --dangerously-skip-permissions
```

> _Recommendation: only yolo on a VM with internet disconnected. Google Cloud Workstations or similar offering is great for this._

### 3. Write a detailed prompt

```bash
# job_instructions.md
"Your job is to rewrite our entire React site to htmx because... well forget why. Just do it.

I'm going to include other specific instructions here; the more, the better at this stage because as an Orchestrator Agent you will distill down what is important for each agent. :) "
```

### 3. Start the Orchestrator Agent

```bash
# First prompt loads the agent instructions
/orchestrator

# Second prompt you provide the job instructions
"here is your task: @job_instructions.md"
```

## Key Principles
Obviously parallelization is cool. But this toolchain is about much more than just sloppily running a lot of Claude Code instances at once.

It is about these fundamental principles:
- shorter context window improves coding reliability (https://arxiv.org/html/2505.07897v2)
- shorter task length improves reliability (https://arxiv.org/html/2504.21751v2)
- reflexion improves reliability (https://arxiv.org/abs/2303.11366)

So we want to provide our AI coding agents with the smallest possible task and nothing more. We want the context to be short. We want the task to be well-defined and easily testable. And we want another agent to validate the output of the first agent.

## Inspiration: Reliability Engineering
There is a now-famous analysis by METR (https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/) which shows that the length of a task that an AI coding agent can complete has been doubling every 7 months.

While this fact has its own implications, the thing that interested me the most was that they measured it by completion with 80% reliability. 

That got me thinking - can we stack on redundancy layers and distillation steps to improve frontier model performance to move the needle closer to 100%?

For example, if we break a very long task down into subtasks and have a separate agent complete each one independently, does this improve the overall reliability of the system? If we add on a reflexion layer, does that further improve our results?

Anecdotally, the answer seems to be yes. We would appreciate help in benchmarking this approach as a "scaffold" for LLM tooling. Ideally, labs that are working on long-horizon RL for coding agents should borrow from our scaffold concepts here.

## How it works

Multiagent Code decomposes big coding problems into many small, parallel jobs handled by AI agents. 

There are 3 generalist agent types:
- **Orchestrator**: you interact directly with this one via the top-level interactive Claude Code instance. The Orchestrator's job is to break the task down into atomic jobs and assign those off to Manager agents with a custom prompt for each job.
- **Manager**: Each manager is assigned one very small job (ex: edit this one file) and deploys a single worker to execute the code changes. The manager is only responsible for reviewing the final output and marking it as pass/fail. It can work collaboratively with the worker if required.
- **Worker**: This is the only agent that actually makes the code changes. It receives instructions from the manager. The manager will optionally provide follow-up instructions until the quality is satisfactory.

The pipeline rests on four key processes:

1. **Interpolative Prompting**  
   Using a detailed instruction prompt for the Orchestrator, we tell it how to write a simple bash script that creates N custom prompts, one for each job. Each prompt will usually share a lot of static content based on the task, along with some dynamic fields (such as the specific file that is assigned to this job).  

2. **Hierarchical Delegation & Reflexion**  
   Each prompt goes to a _manager_ agent, who immediately delegates the work to a _worker_ agent. The manager then audits the result; if anything is missing it resumes the same worker session with targeted feedback. This self-critique loop ("reflexion") greatly improves reliability without human review (See 2023 Reflexion paper: https://arxiv.org/abs/2303.11366)

3. **Lightweight Monitoring**  
   Manager and worker processes stream JSON logs to disk. A monitor script watches PIDs and scans logs for the strings `ORCHESTRATOR_STATUS: SUCCESS` or `FAILURE`, giving the orchestrator an instant, scalable health check across thousands of jobs.

4. **Automatic Error Recovery**  
   When a task fails, the monitor extracts the session-id, writes a structured `FAILURE` report with a ready-to-copy resume command, and halts the run. You can tweak the prompt or supply corrections and resume the exact same session—preserving all prior context.

Because the entire stack is shell-based, you can easily adjust retry logic, or insert custom analysis stages with only a few lines of Bash.

## When to use Multiagent Code

This tool is best used for parallelizing a similar task across many files, especially for a large migration. If you wish you could write a magic AI codemod for a certain task, this toolchain is probably for you.

If the task is small, probably stick with just /clear and move on.

## Hackable by Default

Since you will have this repo cloned locally and Claude Code just executes commands and reads instructions from here, it is super easy to change the behavior and capabilities of your agents (and debug when they are going wrong).

If you come up with any awesome ideas, consider writing an upstream PR!

## Demo

https://www.loom.com/share/99cb8f82c01f4213bf1c82ab4212a8fb

### Rate Limits and Token Usage Notes

Since this tool uses lots of parallel requests, you probably want to use API authentication instead of a subscription. You will quickly hit your subscription rate limit and it will render the tool ineffective.

Also, Claude 4 is way too expensive for how intelligent it is. o4-mini presents similar performance on coding tasks with less cost. It is a key concept of this tool to do more smaller requests, so the same applies to the model selection. It's better to pick something 2x as cheap because then you can afford to parallelize a reviewr for "reflexion".

### Usage with OpenAI, Gemini, other Non-Anthropic Models

Believe it or not, you can actually run Claude Code with any model provider (OpenAI, Gemini, etc) using a relay service. We recommend setting up https://github.com/fuergaosi233/claude-code-proxy There is another one out there with a similar name, but as of July 2025, this is the best one.

### Default Timeout Duration

Claude Code has a default timeout for commands of 2 minutes. Our orchestrator agent will run a monitoring script that usually runs much longer while all of the jobs run. Our installation script will set the Claude Code default timeout to 20 minutes on your machine. Change this using `BASH_DEFAULT_TIMEOUT_MS=1200000`
