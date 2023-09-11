print("Importing")
import json
import numpy as np
import pandas as pd
import gurobipy as gp
from gurobipy import GRB
import time
import utils

print("Setting environment", flush=True)
# Create an environment with your WLS license
params = {
"WLSACCESSID": 'secret',
"WLSSECRET": 'secret',
"LICENSEID": secret,
}

env = gp.Env(params=params)

# Create the model within the Gurobi environment
model = gp.Model(env=env)

print("Pre-processing", flush=True)
day_Information = utils.DayInformation('DataProject/DataProject/Events18.csv','DataProject/DataProject/students_small.json')
day_Information.fill_matrix() # (nb_of_students, nb_of_lectures) matrix
day_Information.fill_df()
day_Information.fill_incompatible_dict()
day_Information.fill_ordered_courses_for_student()
room = utils.Room("DataProject/DataProject/SallesDeCours.csv", 'DataProject/DataProject/distances.xlsx',1)
room.fill_matrix() # (nb_of_lectures, nb_of_lectures) matrix
enrollement = day_Information.matrix
nb_of_students = day_Information.matrix.shape[0]
nb_of_lectures = day_Information.matrix.shape[1]
nb_of_rooms = room.distance_matrix.shape[0]

print("Formulating the problem", flush=True)
start = time.time()
# Create a new model
model = gp.Model(env=env)

# Create variables
x = model.addMVar((nb_of_lectures, nb_of_rooms), vtype=GRB.BINARY, name = "x_{i,j}")
y = model.addMVar((nb_of_lectures,), vtype=GRB.INTEGER, name = "y_i") #Non-optimizable variable
c = model.addMVar((nb_of_rooms,), vtype=GRB.INTEGER, name = "C_j") #Non-optimizable variable
s = model.addMVar((nb_of_students, nb_of_lectures), vtype=GRB.BINARY, name = "S_{i,j}") #Non-optimizable variable
cap_slacks = model.addVars(nb_of_rooms, lb=0, vtype=GRB.CONTINUOUS, name = "capacity slacks")
alpha = 0.8
end = time.time()
print(f"Model created in {round(end-start,3)} \n", flush=True)


start = time.time()
# Add constraints
# First we add the constraints over the non-optimizable variables (either by for loop or by M)

#   Constraint for the capacity
model.addMConstr(A = np.identity(nb_of_rooms, dtype=int), x = c, sense =  '=', b = room.capacities )
#   Constraint for the number of student following course i
model.addMConstr(A = np.identity(nb_of_lectures, dtype=int), x = y, sense = '=', b = day_Information.nb_of_students_per_course)
#   Constraint to account for the enrollement of students in their respective classes 
for i in range(int(nb_of_lectures/1)):
    model.addMConstr(A = np.identity(nb_of_students, dtype=int), x = s[:,i], sense = '=', b = enrollement[:,i] )
end = time.time()
print(f"Static constraints added in {round(end-start,3)} \n", flush=True)


start = time.time()
# Then we add the constraints that drive the dynamics of the problem

#   Constraint stating that every lecture should have a room 
for i in range(int(nb_of_lectures/1)):
    model.addConstr(gp.quicksum(x[i,j] for j in range(nb_of_rooms)) == 1)
print("First dynamic constraint added", flush=True)

#   Constraint stating that rooms should be large enough (choose between one of the 2)
for j in range(nb_of_rooms):
    model.addConstr( gp.quicksum(x[i,j]*y[i] for i in range(nb_of_lectures)) <= c[j] )

# for i in range(int(nb_of_lectures/1)):
#     for j in range(nb_of_rooms):
#         model.addConstr(x[i,j]*y[i] <= c[j] + cap_slacks[j]) # disaggregated is better!

print("Second dynamic constraint added", flush=True)
#   Constraint stating that 2 incompatible courses cannot be given in the same class
for i in range(int(nb_of_lectures/1)):
    for j in range(int(nb_of_rooms/1)):
        for i_tilde in day_Information.incompatible_courses_array[i]:
            model.addConstr(x[i,j]+x[i_tilde,j] <= 1) 
end = time.time()

print(f"Dynamic constraints added in {round(end-start,3)} \n", flush=True)

start = time.time()


qexpr = 0
for s in range(int(nb_of_students)):
    student_courses = day_Information.ordered_courses_for_student[s] 
    for i in range(len(student_courses)-1):
        qexpr += x[student_courses[i],:] @ room.distance_matrix[:,:] @ x[student_courses[i+1],:]
            
slack_expr = 0
# Add the slacks to minimize as well with a certains 
for j in range(nb_of_rooms):
    slack_expr += cap_slacks[j]

obj_expr = alpha*qexpr + (1-alpha)*slack_expr

model.setObjective(obj_expr, GRB.MINIMIZE)
end = time.time()

print(f"Objective function added in {round(end-start,3)} \n", flush=True)



# get the number of variables and constraints
num_vars = model.NumVars
num_constrs = model.NumConstrs

# print the model size
print("Model size:", flush=True)
print(f"- Number of variables: {num_vars}", flush=True)
print(f"- Number of constraints: {num_constrs}", flush=True)


model.optimize()

model.write("Room_allocation_solution.sol")
model.write("Room_allocation_solution.rlp")
