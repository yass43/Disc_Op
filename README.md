# Room Allocation Optimization Project

## Introduction

This repository contains the code and findings for solving the room allocation problem for the University of Liège. The room allocation problem involves assigning course rooms to lectures in a way that minimizes the average distance traveled by students. Efficient room allocation not only benefits students but also contributes to environmental sustainability.

### Problem Description

The room allocation problem consists of the following key elements:

- Allocating course rooms to lectures.
- Ensuring each lecture is assigned to exactly one room with sufficient capacity.
- Allowing rooms to be assigned to several courses as long as they don't have schedule conflicts.

### Motivation

Efficient room allocation is crucial for several reasons, including:

- **Environmental Sustainability:** Minimizing student travel distance reduces the environmental impact of commuting.

### Approach

We initially attempted to solve this problem using a discrete optimization solver but encountered challenges in achieving a small lower-upper bound gap within reasonable computing time. To address this, we proposed and implemented several heuristics to improve efficiency. Additionally, we compared these heuristics and evaluated their performance.


## Getting Started

To get started with this project, follow these steps:

1. Clone the repository to your local machine:

   ```bash
   git clone "https://github.com/yass43/Disc_Op.git"
