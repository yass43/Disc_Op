using CSV
using JSON
using DataFrames
using DataStructures
using XLSX
using Statistics
using Plots
using DelimitedFiles

function overlap(event1, event2)
    start1, end1 = event1["Start"], event1["End"]
    start2, end2 = event2["Start"], event2["End"]
    if end1 <= start2 
        return false
    end
    if start1 >= end2 
        return false
    end
    return true
end

Base.@kwdef mutable struct Students_Courses_str
    event_path::String
    student_path::String
    student_ids::Vector= zeros(Int,1)
    stu_size::Int = 1
    course_data::DataFrame =DataFrame(A = [1], B = ["a"], C = [true])
    cou_size::Int = 1
    S::Array = zeros(Int,1,1)
    stu_per_cou::Vector = zeros(Int,3)
    cou_per_stu::Vector = zeros(Int,3)
    INC::Array = zeros(Int,1,1)
end

function populate_student_courses(st_cr::Students_Courses_str)
    json_string = read(st_cr.student_path, String)
    student_data = JSON.parse(json_string)
    st_cr.student_ids = unique(reduce(vcat, collect(values(student_data))))
    st_cr.stu_size = size(st_cr.student_ids)[1]

    st_cr.course_data = CSV.read(st_cr.event_path,DataFrame, delim="\t", header=true,
    types=[String, String, String, String])
    st_cr.course_data = sort(st_cr.course_data, :Start)
    st_cr.cou_size = size(st_cr.course_data)[1]
    
    st_cr.S = zeros(Int,st_cr.stu_size,st_cr.cou_size)
    for i in 1:st_cr.stu_size
        for j in 1:st_cr.cou_size
            st_cr.S[i,j] = in(st_cr.student_ids[i], student_data[st_cr.course_data.Event[j]]) ? 1 : 0
        end
    end
    st_cr.stu_per_cou = vec(sum(st_cr.S, dims =1))
    st_cr.cou_per_stu = vec(sum(st_cr.S, dims =2))
    st_cr.INC = zeros(Int, st_cr.cou_size, st_cr.cou_size)
    for i in 1:st_cr.cou_size
        for j in (i+1):st_cr.cou_size
            if overlap(st_cr.course_data[i, :],st_cr.course_data[j, :])
                st_cr.INC[i,j] = st_cr.INC[j,i] = 1
            end
        end
    end  
end

Base.@kwdef mutable struct rooms_str
    rooms_path::String
    distance_path::String
    capacity::Vector= zeros(Int,1)
    nb_rooms::Int = 1
    distance_frame::DataFrame =DataFrame(A = [1], B = ["a"], C = [true])
    room_data::DataFrame =DataFrame(A = [1], B = ["a"], C = [true])
    distance_matrix::Array = zeros(Int,1,1)
end

function populate_rooms(rm_str::rooms_str)
    rm_str.room_data = CSV.read(rm_str.rooms_path, DataFrame, delim=";", header=true, types=[ String, String, String, Int, String, String])
    rm_str.nb_rooms= size(rm_str.room_data)[1]
    
    distance_data = XLSX.readdata(rm_str.distance_path, 1,  "B2:J10")
    rm_str.distance_frame = DataFrame(distance_data, :auto)
    rm_str.distance_frame.rowname = ['A', 'B', 'E' , 'F' , 'I' ,'J' , 'L',  'N' , 'O']
    rm_str.distance_frame = rename(rm_str.distance_frame,["A", "B", "E" , "F" , "I" ,"J" , "L",  "N" , "O","rowname"])
    for i in 1:size(rm_str.distance_frame)[1]
        for j in (i+1):(size(rm_str.distance_frame)[2]-1)
            rm_str.distance_frame[j,i] = rm_str.distance_frame[i,j]
        end
    end

    rm_str.capacity = rm_str.room_data[:,4]

    rm_str.distance_matrix = zeros(Int, rm_str.nb_rooms, rm_str.nb_rooms)
    for i in 1:rm_str.nb_rooms
        i_build = rm_str.room_data[i, :Building]
        for j in (i+1):rm_str.nb_rooms
            j_build = rm_str.room_data[j, :Building]
            if i_build != j_build
                boogie = findall(rm_str.distance_frame[:, :rowname] .== i_build[1])[1]
                doogie = findall(names(rm_str.distance_frame).== string(j_build[1]))[1]
                rm_str.distance_matrix[i,j] = rm_str.distance_matrix[j,i] = rm_str.distance_frame[boogie,doogie]
            end
        end
    end
end

# Reduce number of students in each class to max 1.5*average
function analysis(st_cr::Students_Courses_str, rrm_str::rooms_str)
    json_string = read(st_cr.student_path, String)
    student_data = JSON.parse(json_string)
    mapos = map(length, collect(values(student_data)))
    avg = round(1.5*mean(mapos))
    plot()
    histogram(mapos, bins = 60, title = "Histogram: # of Students/Course")
    xticks!(0:50:600)
    savefig("HistogramStudentsCourse15.png")
    for (key, value) in student_data
        # student_data[key] = value[1:minimum([Int(avg), length(value)])]
        student_data[key] = value[1:Int(round(length(value)*3/5))]
    end
    mapos = map(length, collect(values(student_data)))
    plot()
    histogram(mapos, bins = 60, title = "Histogram: # of Students/Course After mean haircut")
    xticks!(0:50:600)
    savefig("HistogramStudentsCourseaftermean15.png")
    json_string = JSON.json(student_data)

    # Save the JSON string to a file
    tranche = st_cr.student_path[end-14:end-5]
    file_path = "DataProject/DataProject/$tranche.15.json"
    open(file_path, "w") do file
        write(file, json_string)
    end
    
    plot()
    histogram(rrm_str.capacity, bins = 60, title = "Histogram: Room capacity")
    xticks!(0:50:600)
    savefig("HistogramRoomcapacity15.png")
end

st_cr_18 = Students_Courses_str(event_path="DataProject/DataProject/Events18.csv",student_path ="DataProject/DataProject/students.15.json")
populate_student_courses(st_cr_18)
rrm_str_18 = rooms_str(rooms_path="DataProject/DataProject/SallesDeCours.csv",distance_path="DataProject/DataProject/distances.xlsx")
populate_rooms(rrm_str_18)

# analysis(st_cr_18, rrm_str_18)

# println(rrm_str_18.rooms_path)
# println(rrm_str_18.distance_path)
# println(rrm_str_18.capacity)
println(rrm_str_18.nb_rooms)
println(rrm_str_18.distance_frame)
# println(rrm_str_18.room_data)
# println(rrm_str_18.distance_matrix)

# println(st_cr_18.event_path)
# println(st_cr_18.student_path)
# println(st_cr_18.student_ids)
println(st_cr_18.stu_size)
# println(st_cr_18.course_data)
# println(st_cr_18.cou_size)
# println(st_cr_18.S)
# println(st_cr_18.stu_per_cou)
# println(st_cr_18.cou_per_stu)
# println(st_cr_18.INC)


# nmbers common between all courses
# json_string = read(st_cr_18.student_path, String)
# student_data = JSON.parse(json_string)

# inter = zeros(Int, st_cr_18.cou_size, st_cr_18.cou_size)
# for i in 1:st_cr_18.cou_size
#     for j in (i+1):st_cr_18.cou_size
#         inter[i,j] = inter[j,i] = length(intersect(student_data[st_cr_18.course_data[i, :Event]], student_data[st_cr_18.course_data[j, :Event]]))
#     end
# end

# function commenize(i,j,inter)
#     # number of students in common
#     soc = inter[i,j]
#     # number of common courses with non-zero intersection
#     if i != j
#         cci = length(intersect(findall(inter[i,:] .> 0), findall(inter[j,:] .> 0)))
#     else
#         cci = 0
#     end
#     common = soc + 5*cci
#     return common
# end

# function similarity(clusters, inter)
#     simi=0
#     for clus in clusters
#         for p in 1:length(clus)
#             for j in (p+1):length(clus)
#                 simi = simi + inter[clus[p],clus[j]]
#             end
#         end
#     end
#     return simi
# end

# function clusteringzz(inter, st_cr_18, rrm_str_18, K)
#     # select K centroids 
#     old_centroids = []
#     k = 1
#     while k <= K
#         c = rand(1:st_cr_18.cou_size)
#         if c in old_centroids
#             continue
#         end
#         k=k+1
#         push!(old_centroids,c)
#     end
#     # println("old centroids: $old_centroids")
#     old_clusters = []
#     for k in 1:K
#         push!(old_clusters, [old_centroids[k]])
#     end

#     # each point with the most similar centroid
#     for i in 1:st_cr_18.cou_size
#         if i in old_centroids
#             continue
#         end
#         measure_list = []
#         for k in 1:K
#             push!(measure_list, commenize(i, old_centroids[k], inter))
#         end
#         push!(old_clusters[findmax(measure_list)[2]], i)
#     end
#     # println("old clusters: $old_clusters")

#     new_clusters = []
#     flag = false
#     while flag == false
#         println("Hello")
#         simos = similarity(old_clusters, inter)
#         println("Similarity:  $simos ")
#         # calculate new centroids, the point in cluster with the highest average similarity to the other points in cluster
#         new_centroids = []
#         for cluster in old_clusters
#             avg_similarities = []
#             for p in 1:length(cluster)
#                 avv = 0
#                 for j in 1:length(cluster)
#                     avv = avv + commenize(cluster[p], cluster[j], inter)
#                 end
#                 push!(avg_similarities, avv/length(cluster))
#             end
#             push!(new_centroids, cluster[findmax(avg_similarities)[2]])
#         end
#         # println("new centroids: $new_centroids")
#         # put each centroid in its own list
#         for k in 1:K
#             push!(new_clusters, [new_centroids[k]])
#         end
#         # each point with the most similar centroid
#         for i in 1:st_cr_18.cou_size
#             if i in new_centroids
#                 continue
#             end
#             measure_list = []
#             for k in 1:K
#                 push!(measure_list, commenize(i, new_centroids[k], inter))
#             end
#             push!(new_clusters[findmax(measure_list)[2]], i)
#         end

#         # println("new clusters: $new_clusters")
#         # until convergence
#         flag = true
#         for k in 1:K
#             if length(intersect(old_clusters[k], new_clusters[k]))<0.99*length(old_clusters[k])
#                 flag = false
#             end
#         end
#         if flag == false
#             old_clusters = new_clusters[:,:]
#             new_clusters = []
#         end
#         breaker = readdlm("breaker.txt")
#         if breaker[1,1] == 0
#             break
#         end
#     end
#     return new_clusters
# end

# jados = clusteringzz(inter, st_cr_18, rrm_str_18, 9)




# Quels sont les cours qui qui sont pris par des cours qui prennent d'autres cours
# S stu_size course_size

# list_of_courses = []
# size(st_cr_18.S)
# stuuz = findall(sum(st_cr_18.S .==1,dims= 2) .> 1)
# for i in 1:length(stuuz)
#     push!(list_of_courses, findall(st_cr_18.S[stuuz[i][1],:] .==1))
# end
# println(list_of_courses)
# list_of_courses = unique(reduce(vcat, collect(list_of_courses)))
# sort(list_of_courses)



# course_data still sorted by start time
# course_data = hcat(st_cr_18.course_data, st_cr_18.stu_per_cou)
# # new data frame sorted by stuedent capacity
# rename!(course_data, :x1 => :Students)
# sorted_courses_by_students = sort(course_data, :Students,rev=true)
# sorted_courses_by_time = sort(course_data, :Start)
# # should create a matrix S that respects this order
# # S = zeros(Int,st_cr_18.stu_size,st_cr_18.cou_size)
# # for i in 1:st_cr_18.stu_size
# #     for j in 1:st_cr_18.cou_size
# #         S[i,j] = in(st_cr_18.student_ids[i], student_data[sorted_courses_by_students.Event[j]]) ? 1 : 0
# #     end
# # end
# # should create also incompatibility matrix with this order
# INC = zeros(Int, st_cr_18.cou_size, st_cr_18.cou_size)
# for i in 1:st_cr_18.cou_size
#     for j in (i+1):st_cr_18.cou_size
#         if overlap(sorted_courses_by_students[i, :],sorted_courses_by_students[j, :])
#            INC[i,j] = INC[j,i] = 1
#         end
#     end
# end  

# # Sort rooms by there capacity
# sorted_rooms = sort(rrm_str_18.room_data, :Capacity,rev=true)
# capacity = sorted_rooms[:,4]

# take K first elements of courses and make compatible subsets
# K=150
# ran = rand(1:K)
# compos = [j for j in findall(INC[ran,1:K] .== 0)]
# new_compos = []
# flagos = true
# jert = 0
# while flagos
#     ran = rand(compos)
#     new_compos = [j for j in findall(INC[ran,1:K] .== 0) if j in compos]
#     if compos == new_compos
#         jert = jert + 1
#         if jert > 2
#             flagos = false
#         else
#             compos = new_compos[:]  
#         end
#     else
#         jert = 0
#         compos = new_compos[:]
#     end
# end
# compos

# composis = [j for j in 1:K if !in(j, compos)]
# then get final composis

function set_me_up(rangos, listos)
    # println("listos: $listos")
    ran = rand(listos)
    # println("first_ranos: $ran")
    compos = [j+rangos[1]-1 for j in findall(INC[ran,rangos] .== 0) if j+rangos[1]-1 in listos]
    # println("first_compos: $compos")
    new_compos = []
    flagos = true
    jert = 0
    while flagos
        # println("boom: $compos")
        ran = rand(compos)
        # println("ran: $ran")
        new_compos = [j+rangos[1]-1 for j in findall(INC[ran,rangos] .== 0) if j+rangos[1]-1 in compos]
        # println("new_compos: $new_compos")
        if compos == new_compos
            jert = jert + 1
            if jert > length(compos)
                flagos = false
            else
                compos = new_compos[:]
            end
        else
            jert = 0
            compos = new_compos[:]
        end
        # println("new new compos: $compos")
    end
    return compos
end

function give_me_my_sets(rangos)
    my_sets = []
    push!(my_sets, set_me_up(rangos, rangos))
    while sum(map(length, my_sets)) != length(rangos)
        # println(length(my_sets))
        # println(my_sets[end])
        # println(reduce(vcat, collect(my_sets)))
        bug = [j for j in rangos if !in(j, (reduce(vcat, collect(my_sets))))]
        # println(bug)
        push!(my_sets, set_me_up(rangos,bug)) 
        breaker = readdlm("breaker.txt")
        if breaker[1,1] == 0
            break
        end
    end
    return my_sets
end

# buga  = give_me_my_sets(1:150)
# println("YAAAAASSSS:   $buga")
# length(unique(reduce(vcat, buga)))

# bugas = []
# for i in 1:20
#     push!(bugas, give_me_my_sets(151:300))
# end

# println(map(length, bugas))



# using Clustering


# # Generate some random data
# coursiss = sorted_courses_by_students[:, :Students]
# quantile!(coursiss, [1/(6-j) for j in 1:4])
# using Statistics
# # Reshape the data to a column vector
# coursiss  = reshape(coursiss , :, 1)
# # Perform k-means clustering with k = 3
# k = 7
# coursiss_result = kmeans(coursiss', k)
# fieldnames(typeof(coursiss_result))
# # Get the cluster assignments and centroids
# coursiss_assignments = coursiss_result.assignments
# coursiss_centroids = coursiss_result.centers
# coursiss_clusters=[length(findall(coursiss_assignments .==k)) for k in 1:K]

# cluu = hcat(coursiss_result.counts[:], map(round, coursiss_centroids[:]))
# sorted_indices = sortperm(cluu[:, 2])
# cluu_sorted = cluu[sorted_indices, :]
# cluu_sorted[:,1]

# # Generate some random data
# roomsies = capacity[:]
# # Reshape the data to a column vector
# roomsies = reshape(roomsies, :, 1)
# # Perform k-means clustering with k = 3
# K = 7
# roomsies_result = kmeans(roomsies', k)
# # Get the cluster assignments and centroids
# roomsies_assignments = roomsies_result.assignments
# roomsies_centroids = roomsies_result.centers
# roomsies_clusters=[length(findall(roomsies_assignments .==k)) for k in 1:K]


# clii = hcat(roomsies_result.counts[:], map(round, roomsies_centroids[:]))
# sorted_indices = sortperm(clii[:, 2])
# clii_sorted = clii[sorted_indices, :]

# clui = hcat(cluu_sorted, clii_sorted)

# get the range and do sorted_courses_by_students

# okay so i have a subset i get the max students sort the subsets and assign room
# by 
# clusters = [52,58,60,112,208]
# bugas = []
# for i in 1:length(clusters)
#     rangos = sum(clusters[1:i-1])+1:sum(clusters[1:i])
#     println(rangos)
#     push!(bugas , give_me_my_sets(rangos))
# end
# jadoxx = reduce(vcat, collect(bugas))

function my_length(listi)
    return maximum(sorted_courses_by_students[listi, :Students])
end

# requirements = map(my_length, jadoxx)

# my_reduced = hcat(requirements, jadoxx)
# sorted_indices = sortperm(my_reduced[:, 1], rev = true)
# my_reduced_sorted = my_reduced[sorted_indices, :]

# size(jadoxx)[1]-length(findall(capacity[1:size(my_reduced_sorted)[1]] .>= vec(my_reduced_sorted[:,1])))

# hcat(capacity[1:size(my_reduced_sorted)[1]] , vec(my_reduced_sorted[:,1]))

# XXX = zeros(Int, st_cr_18.cou_size, rrm_str_18.nb_rooms)

# for subset in 1:size(my_reduced_sorted)[1]
#     for course in my_reduced_sorted[subset,2]
#         XXX[course,subset]=1
#     end
# end

# for i in 1:st_cr_18.cou_size
#     print(sum(XXX[i,:]) == 1 ? 1 : 0)
# end

# for j in 1:st_cr_18.cou_size
#     print(transpose(XXX[j,:])*capacity[:] >= sorted_courses_by_students[:, :Students][j] ? 1 : 0)
# end

# for i in 1:st_cr_18.cou_size
#     searchs = findall(INC[i, :] .== 1) #### Can be done outside optimizer
#     for j in 1:size(searchs)[1]
#         if searchs[j] >= i
#             print(XXX[i,:] + XXX[searchs[j],:] <= ones(rrm_str_18.nb_rooms)  ? 1 : 0)
#         end
#     end
# end


# # permutation indices from sorted by start to sorted by students
# mapping_start_to_students = sortperm(sorted_courses_by_time[:, :Students])

# distance_matrix = zeros(Int, rrm_str_18.nb_rooms, rrm_str_18.nb_rooms)
# for i in 1:rrm_str_18.nb_rooms
#     i_build = sorted_rooms[i, :Building]
#     for j in (i+1):rrm_str_18.nb_rooms
#         j_build = sorted_rooms[j, :Building]
#         if i_build != j_build
#             boogie = findall(rrm_str_18.distance_frame[:, :rowname] .== i_build[1])[1]
#             doogie = findall(names(rrm_str_18.distance_frame).== string(j_build[1]))[1]
#             distance_matrix[i,j] = distance_matrix[j,i] = rrm_str_18.distance_frame[boogie,doogie]
#         end
#     end
# end

# Objective Function
function calculate_objoctos(st_cr, rrm_str, x, mappings, distance_matrix)
    total_distance = 0
    for s in 1:st_cr.stu_size
        # println(s/st_cr.stu_size*100)
        coucous = findall(st_cr.S[s,:] .== 1) #### can be done outside optimizer
        for cor in 1:(size(coucous)[1]-1)
            total_distance = total_distance + transpose(x[mappings[coucous[cor]], :])*distance_matrix*x[mappings[coucous[cor+1]], :]
        end
    end
    return total_distance
end

function calculate_objoctos_lower(st_cr)
    total_distance = 0
    for s in 1:st_cr.stu_size
        # println(s/st_cr.stu_size*100)
        coucous = findall(st_cr.S[s,:] .== 1) #### can be done outside optimizer
        for cor in 1:(size(coucous)[1]-1)
            total_distance = total_distance + 8
        end
    end
    return total_distance
end
calculate_objoctos_lower(st_cr_18)



function generate_and_rate()

    json_string = read(st_cr_18.student_path, String)
    student_data = JSON.parse(json_string)
    course_data = hcat(st_cr_18.course_data, st_cr_18.stu_per_cou)
    # new data frame sorted by stuedent capacity
    rename!(course_data, :x1 => :Students)
    sorted_courses_by_students = sort(course_data, :Students,rev=true)
    sorted_courses_by_time = sort(course_data, :Start)

    INC = zeros(Int, st_cr_18.cou_size, st_cr_18.cou_size)
    for i in 1:st_cr_18.cou_size
        for j in (i+1):st_cr_18.cou_size
            if overlap(sorted_courses_by_students[i, :],sorted_courses_by_students[j, :])
            INC[i,j] = INC[j,i] = 1
            end
        end
    end  

    sorted_rooms = sort(rrm_str_18.room_data, :Capacity,rev=true)
    capacity = sorted_rooms[:,4]
    v1 = rand(40:65)
    v2 = rand(40:70)
    v3 = rand(40:80)
    v4 = rand(80:120)
    v5 = st_cr_18.cou_size - (v1+v2+v3+v4)

    
    clusters = [v1,v2,v3,v4,v5]
    bugas = []
    for i in 1:length(clusters)
        rangos = sum(clusters[1:i-1])+1:sum(clusters[1:i])
        println(rangos)
        push!(bugas , give_me_my_sets(rangos))
    end
    jadoxx = reduce(vcat, collect(bugas))
    requirements = map(my_length, jadoxx)

    my_reduced = hcat(requirements, jadoxx)
    sorted_indices = sortperm(my_reduced[:, 1], rev = true)
    my_reduced_sorted = my_reduced[sorted_indices, :]

    size(jadoxx)[1]-length(findall(capacity[1:size(my_reduced_sorted)[1]] .>= vec(my_reduced_sorted[:,1])))

    hcat(capacity[1:size(my_reduced_sorted)[1]] , vec(my_reduced_sorted[:,1]))

    XXX = zeros(Int, st_cr_18.cou_size, rrm_str_18.nb_rooms)

    for subset in 1:size(my_reduced_sorted)[1]
        for course in my_reduced_sorted[subset,2]
            XXX[course,subset]=1
        end
    end
    cc1 = [] 
    for i in 1:st_cr_18.cou_size
        push!(cc1, sum(XXX[i,:]) == 1 ? 1 : 0)
    end
    if (minimum(cc1)== 1)
        println("CONST 1 OKAAAYYY")
    else 
        println("CONST 1 BAAADD")
    end

    cc2 = []
    for j in 1:st_cr_18.cou_size
        push!(cc2, transpose(XXX[j,:])*capacity[:] >= sorted_courses_by_students[:, :Students][j] ? 1 : 0)
    end
    if (minimum(cc2)== 1)
        println("CONST 2 OKAAAYYY")
    else 
        println("CONST 2 BAAADD")
    end
    
    cc3 = []
    for i in 1:st_cr_18.cou_size
        searchs = findall(INC[i, :] .== 1) #### Can be done outside optimizer
        for j in 1:size(searchs)[1]
            if searchs[j] >= i
                push!(cc3,XXX[i,:] + XXX[searchs[j],:] <= ones(rrm_str_18.nb_rooms)  ? 1 : 0)
            end
        end
    end
    if (minimum(cc3)== 1)
        println("CONST 3 OKAAAYYY")
    else 
        println("CONST 3 BAAADD")
    end


    # permutation indices from sorted by start to sorted by students
    mapping_start_to_students = sortperm(sorted_courses_by_time[:, :Students])

    distance_matrix = zeros(Int, rrm_str_18.nb_rooms, rrm_str_18.nb_rooms)
    for i in 1:rrm_str_18.nb_rooms
        i_build = sorted_rooms[i, :Building]
        for j in (i+1):rrm_str_18.nb_rooms
            j_build = sorted_rooms[j, :Building]
            if i_build != j_build
                boogie = findall(rrm_str_18.distance_frame[:, :rowname] .== i_build[1])[1]
                doogie = findall(names(rrm_str_18.distance_frame).== string(j_build[1]))[1]
                distance_matrix[i,j] = distance_matrix[j,i] = rrm_str_18.distance_frame[boogie,doogie]
            end
        end
    end
    return XXX, calculate_objoctos(st_cr_18, rrm_str_18, XXX, mapping_start_to_students, distance_matrix)
end


multi_scores = []
multi_soluti = []
for i in 1:250
    solu, scor = generate_and_rate()
    push!(multi_scores ,scor)
    push!(multi_soluti ,solu)
end
done = minimum(multi_scores)
dine = maximum(multi_scores)
println("My_best: $done")
