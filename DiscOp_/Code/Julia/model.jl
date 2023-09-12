include("Structure.jl")
using JuMP, Gurobi

st_cr_18 = Students_Courses_str(event_path="DataProject/DataProject/Events18.csv",student_path ="DataProject/DataProject/students_test.json")
populate_student_courses(st_cr_18)

rrm_str_18 = rooms_str(rooms_path="DataProject/DataProject/SallesDeCours.csv",distance_path="DataProject/DataProject/distances.xlsx")
populate_rooms(rrm_str_18)

function random_start(st_cr, rrm_str)
    A = zeros(st_cr.cou_size, rrm_str.nb_rooms)
    for i in 1:st_cr.cou_size
        j = rand(1:rrm_str.nb_rooms)
        A[i,j] = 1
    end
    return A
end
        
A = random_start(st_cr_18, rrm_str_18)

function modelize_problem(st_cr, rrm_str)
    model = Model(Gurobi.Optimizer)
    alpha = 0.8

    # set_optimizer_attribute(model, "Method", 2) # Use branch-and-cut
    # set_optimizer_attribute(model, "Crossover", 1) # Enable crossover
    # set_optimizer_attribute(model, "Cuts", 2) # Enable all cuts
    # set_optimizer_attribute(model, "CutPasses", 5) # Run cutting plane algorithms multiple times

    # Define decision variables
    @variable(model, x[1:st_cr.cou_size, 1:rrm_str.nb_rooms],Bin)#, start = A)
    # set_start_value.(x, A)
    @variable(model, slk[1:st_cr.cou_size]>= 0, Int)

    println("Variables DONE")
    # Define constraints
    
    # @constraint(model, course_in_room, vec(sum(x, dims=2)) == ones(st_cr.cou_size)) 
    for i in 1:st_cr.cou_size
        @constraint(model, sum(x[i,:]) == 1)
    end
    # @constraint(model, students_fit_in_room, x*rrm_str.capacity + slk >= st_cr.stu_per_cou)
    for j in 1:st_cr.cou_size
        @constraint(model, transpose(x[j,:])*rrm_str.capacity + slk[j] >= st_cr.stu_per_cou[j])
    end

    for i in 1:st_cr.cou_size
        searchs = findall(st_cr.INC[i, :] .== 1) #### Can be done outside optimizer
        for j in 1:size(searchs)[1]
            if searchs[j] >= i
                @constraint(model, x[i,:] + x[searchs[j],:] <= ones(rrm_str.nb_rooms))
            end
        end
    end
    println("Contraintes DONE!!")
    # coucous = []
    # for s in 1:st_cr.stu_size
    #     push!(coucous ,findall(st_cr.S[s,:] .== 1))#### can be done outside optimizer
    # end
    
    function calculate_objoctos(st_cr, rrm_str, x)
        total_distance = 0
        for s in 1:st_cr.stu_size
            println(s/st_cr.stu_size*100)
            coucous = findall(st_cr.S[s,:] .== 1) #### can be done outside optimizer
            for cor in 1:(size(coucous)[1]-1)
                total_distance = total_distance + transpose(x[coucous[cor], :])*rrm_str.distance_matrix*x[coucous[cor+1], :]
                # r = reshape((collect(1:rrm_str.nb_rooms)),1,:)*x[coucous[cor], :]
                # rr = reshape((collect(1:rrm_str.nb_rooms)),1,:)*x[coucous[cor+1], :]
                # r = [j for j in 1:rrm_str.nb_rooms if value(x[coucous[cor], j]) == 1]
                # rr = [j for j in 1:rrm_str.nb_rooms if value(x[coucous[cor+1], j]) == 1]
                # r = findfirst(x[coucous[cor], :] .==1)
                # rr = findfirst(x[coucous[cor+1], :].==1) #### can be used for next iteration
                # total_distance = total_distance + rrm_str.distance_matrix[r,rr]
            end
        end
        return total_distance
    end
    

    # @objective(model, Min, alpha*sum([ rrm_str.distance_matrix[findfirst(x[(coucous[s][cor]), :] .==1),findfirst(x[(coucous[s][cor+1]), :].==1)] for s in 1:(st_cr.stu_size) for cor in 1:(size(coucous[s])-1) ])+(1-alpha)*sum(slk))
    @objective(model, Min, alpha*calculate_objoctos(st_cr, rrm_str, x)+(1-alpha)*sum(slk))
    println("Objective Done!!!!")
    optimize!(model)
    
    return model
end



modo = modelize_problem(st_cr_18, rrm_str_18)

X = [1 0 0; 0 1 0; 0 0 1]
Z = ones(3)

V = [10 0 0;15 0 0;30 0 0]
vv= V[:,1]

Sl = ones(3)
Sl[1:3] = [10 15 10]
Sl

BB = [20 30 40; 0 0 0 ;0 0 0]
B = vec(sum(BB, dims =1)) # = [20 30 40]

C1 = ((vec(sum(X, dims=2))) == Z)

C2 = X*vv + Sl == B
C22= transpose(X[1,:])*vv + Sl[1] == B[1]
nb = zeros(3,2)
nb[1:3,1:2] = [ 1 3;
1 4;
1 6]
nb

println(C2)
C3 = X[1,:]+X[2,:] <= ones(3)
findall(st_cr_18.INC[1, :] .== 1)