---
title: Introduction to Programming
category: Sciences
subject: Computer Science
level: GCE Advanced Level
topic: Foundations of Programming
difficulty: Beginner
creatorId: ai-import
creatorName: Claude
tags: [GCE A-Level, Programming, Computer Science]
---

## What Is Programming

Programming is the process of writing precise, step-by-step instructions that a computer can carry out. A computer does not "understand" a problem the way a person does — it only follows instructions exactly as written, in the order given.

A set of these instructions is called an **algorithm**. Before any code is written, a good programmer first works out the algorithm: the logical sequence of steps needed to solve the problem.

### Why Learn Programming

Programming skills are useful far beyond software careers:

- Automating repetitive tasks
- Analyzing data to find patterns
- Building tools that solve real problems in agriculture, health, education, and business
- Developing logical, structured thinking

### Programming Languages

A **programming language** is a formal language with strict grammar (syntax) that translates human instructions into something a computer's processor can execute. Common examples include Python, JavaScript, Java, and C++. Despite looking different, most languages share the same core building blocks covered in this topic: variables, conditionals, loops, and functions.

### Example: An Everyday Algorithm

Making tea can be written as an algorithm:

1. Boil water
2. Place a tea bag in a cup
3. Pour hot water into the cup
4. Wait 3 minutes
5. Remove the tea bag

Notice each step is unambiguous and happens in a fixed order — exactly what a computer requires.

## Variables and Data Types

A **variable** is a named container that stores a value a program can use and change while it runs.

```
age = 17
name = "Achu"
is_student = true
```

### Common Data Types

- **Integer** — whole numbers, e.g. `17`
- **Float** — decimal numbers, e.g. `3.14`
- **String** — text, e.g. `"Yaoundé"`
- **Boolean** — true or false only

### Why Data Types Matter

The computer treats each type differently. Adding two integers (`2 + 2`) produces `4`, but "adding" two strings (`"2" + "2"`) usually joins them into `"22"`. Choosing the right type avoids subtle, hard-to-find bugs.

[IMAGE: a simple diagram showing a labeled box representing a variable holding a value, with an arrow showing the value being replaced]

## Conditionals and Loops

Real programs rarely run the same steps every single time — they need to make decisions and repeat actions.

### Conditionals

An **if statement** lets a program choose between different actions depending on a condition:

```
if score >= 50:
    print("Pass")
else:
    print("Fail")
```

### Loops

A **loop** repeats a block of instructions, either a fixed number of times or until a condition is met.

- A **for loop** repeats a known number of times, e.g. once for every student in a class list.
- A **while loop** repeats as long as a condition stays true, e.g. keep asking for a password until the correct one is entered.

### Worked Example

Printing all even numbers from 1 to 10:

```
for n in range(1, 11):
    if n % 2 == 0:
        print(n)
```

This combines both ideas: a loop to go through every number, and a conditional to filter only the even ones.

### Practice Questions

1. What data type would best store a person's exact bank balance, and why?
2. Rewrite the tea-making algorithm as numbered steps for making instant noodles.
3. Trace through the even-number loop above by hand and list every number it prints.
