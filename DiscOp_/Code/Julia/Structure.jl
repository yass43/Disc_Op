using CSV
using JSON
using DataFrames
using DataStructures
using XLSX
using Statistics
using Plots

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

# Reduce number of students in each class to the average
function analysis(st_cr::Students_Courses_str, rrm_str::rooms_str)
    json_string = read(st_cr.student_path, String)
    student_data = JSON.parse(json_string)
    mapos = map(length, collect(values(student_data)))
    avg = round(1.5*mean(mapos))
    plot()
    histogram(mapos, bins = 60, title = "Histogram: # of Students/Course")
    xticks!(0:50:600)
    savefig("HistogramStudentsCourse.png")
    for (key, value) in student_data
        student_data[key] = value[1:minimum([Int(avg), length(value)])]
    end
    mapos = map(length, collect(values(student_data)))
    plot()
    histogram(mapos, bins = 60, title = "Histogram: # of Students/Course After mean haircut")
    xticks!(0:50:600)
    savefig("HistogramStudentsCourseaftermean.png")
    json_string = JSON.json(student_data)

    # Save the JSON string to a file
    tranche = st_cr.student_path[end-14:end-5]
    file_path = "DataProject/DataProject/$tranche.50.json"
    open(file_path, "w") do file
        write(file, json_string)
    end
    
    plot()
    histogram(rrm_str.capacity, bins = 60, title = "Histogram: Room capacity")
    xticks!(0:50:600)
    savefig("HistogramRoomcapacity.png")
end

analysis(st_cr_18, rrm_str_18)


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

# st_cr_18 = Students_Courses_str(event_path=
# "C:/Users/jadak/Documents/DISCRETE/PRJ/Disc-Op-Project/DataProject/DataProject/Events18.csv",
# student_path ="C:/Users/jadak/Documents/DISCRETE/PRJ/Disc-Op-Project/DataProject/DataProject/students18.json")
# populate_student_courses(st_cr_18)

##########################"##########################"
##########################"##########################"
function Students_Courses(event_path, student_path)
    json_string = read(student_path, String)
    student_data = JSON.parse(json_string)
    student_ids = unique(reduce(vcat, collect(values(student_data))))
    stu_size = size(student_ids)[1]


    course_data = CSV.read(event_path,DataFrame, delim="\t", header=true, types=[String, String, String, String])
    course_data = sort(course_data, :Start)
    cou_size = size(course_data)[1]

    S = zeros(Int,stu_size,cou_size)
    for i in 1:stu_size
        for j in 1:cou_size
            S[i,j] = in(student_ids[i], student_data[course_data.Event[j]]) ? 1 : 0
        end
    end

    INC = zeros(Int, cou_size, cou_size)
    for i in 1:cou_size
        for j in (i+1):cou_size
            if overlap(course_data[i, :],course_data[j, :])
                INC[i,j] = INC[j,i] = 1
            end
        end
    end

    return student_ids,course_data, S, INC
end


# ss, dd, S, inc = Students_Courses("DataProject/DataProject/Events18.csv","DataProject/DataProject/students18.json")


##########################"##########################"
##########################"##########################"

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


#  rrm_str_18 = rooms_str(rooms_path="DataProject/DataProject/SallesDeCoursff.csv",distance_path="DataProject/DataProject/distances.xlsx")
#  populate_rooms(rrm_str_18)
#  rrm_str_18.capacity

##########################"##########################"
##########################"##########################"


function rooms(rooms_path, distance_path)
    room_data = CSV.read(rooms_path, DataFrame, delim=";", header=true, types=[Int, String, String])
    nb_rooms= size(room_data)[1]
    
    distance_data = XLSX.readdata(distance_path, 1,  "B2:J10")
    distance_frame = DataFrame(distance_data, :auto)
    distance_frame.rowname = ['A', 'B', 'E' , 'F' , 'I' ,'J' , 'L',  'N' , 'O']
    distance_frame = rename(distance_frame,["A", "B", "E" , "F" , "I" ,"J" , "L",  "N" , "O","rowname"])
    for i in 1:size(distance_frame)[1]
        for j in (i+1):(size(distance_frame)[2]-1)
            distance_frame[j,i] = distance_frame[i,j]
        end
    end

    capacity = room_data[:,1]
    println(distance_frame)
    println(capacity)

    distance_matrix = zeros(Int, nb_rooms, nb_rooms)
    for i in 1:nb_rooms
        i_build = room_data[i, :Building]
        for j in (i+1):nb_rooms
            j_build = room_data[j, :Building]
            if i_build != j_build
                boogie = findall(distance_frame[:, :rowname] .== i_build[1])[1]
                doogie = findall(names(distance_frame).== string(j_build[1]))[1]
                distance_matrix[i,j] = distance_matrix[j,i] = distance_frame[boogie,doogie]
            end
        end
    end
    return room_data, distance_frame, capacity, distance_matrix
end


# a, b, c, d =  rooms("DataProject/DataProject/SallesDeCours.csv","DataProject/DataProject/distances.xlsx")