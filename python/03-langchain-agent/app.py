#!/usr/bin/env python3
"""
LangChain Agent example for OISP testing.

Demonstrates tool calling with a simple calculator agent.
"""

import os
import sys

from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langchain_core.tools import tool


@tool
def calculator(expression: str) -> str:
    """Evaluate a mathematical expression. Example: '2 + 3 * 4'"""
    try:
        # Safe evaluation of mathematical expressions
        allowed_chars = set("0123456789+-*/(). ")
        if not all(c in allowed_chars for c in expression):
            return "Error: Invalid characters in expression"
        result = eval(expression)
        return str(result)
    except Exception as e:
        return f"Error: {str(e)}"


@tool
def get_current_year() -> str:
    """Get the current year."""
    from datetime import datetime
    return str(datetime.now().year)


def main():
    # Get API key from environment
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set")
        sys.exit(1)

    print("Creating LangChain agent with tools...")

    # Create the LLM
    llm = ChatOpenAI(
        model="gpt-4o-mini",
        temperature=0,
        api_key=api_key,
    )

    # Define tools
    tools = [calculator, get_current_year]

    # Create the agent using LangGraph
    agent = create_react_agent(llm, tools)

    # Run the agent with a question that requires tool use
    print("\n" + "=" * 50)
    print("Query: What is 15 * 7 + 23?")
    print("=" * 50 + "\n")

    result = agent.invoke({"messages": [("human", "What is 15 * 7 + 23?")]})

    print("\n" + "=" * 50)
    # Get the last message content as the answer
    last_message = result["messages"][-1]
    print(f"Final Answer: {last_message.content}")
    print("=" * 50)

    print("\nDone!")


if __name__ == "__main__":
    main()
