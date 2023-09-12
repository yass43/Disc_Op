import json
import numpy as np
import pandas as pd

def overlap(event1,event2):
    start1, end1 = event1["Start"], event1["End"]
    start2, end2 = event2["Start"], event2["End"]
    if end1 <= start2 :
        return False
    if start1 >= end2 :
        return False
    return True

class DayInformation():
    def __init__(self, event_path, student_path):
        """
        Initializes a DayInformation object with the paths to event and student data files.

        Args:
        - event_path (str): path to the event data file
        - student_path (str): path to the student data file

        Attributes:
        - event_path (str): path to the event data file
        - student_path (str): path to the student data file
        - matrix (numpy.ndarray or None): binary matrix indicating which students are enrolled in which courses
        - df (pandas.DataFrame or None): DataFrame indicating which courses each student is enrolled in
        - cours (pandas.DataFrame): DataFrame containing student course enrollment data
        - data (dict): dictionary containing course enrollment data for each course
        - student_ids (list): list of student IDs
        - course_codes (list): list of course codes
        - student_id_dict (dict): dictionary mapping student IDs to indices in the binary matrix
        - course_code_dict (dict): dictionary mapping course codes to indices in the binary matrix
        """
        self.event_path = event_path
        self.student_path = student_path
        self.matrix = None
        self.df = None
        self.events = pd.read_csv(self.event_path, delimiter='\t')
        with open(self.student_path) as f:
            data = json.load(f)
        self.data = data
        self.student_ids = sorted(set(sum(self.data.values(), [])))
        self.course_codes = sorted(self.data.keys())
        self.student_id_to_index_dict = {student_id: i for i, student_id in enumerate(self.student_ids)}
        self.student_index_to_id_dict = {v: k for k, v in self.student_id_to_index_dict.items()}
        self.course_code_dict_name_to_index = {code: i for i, code in enumerate(self.course_codes)}
        self.course_code_dict_index_to_name = {v: k for k, v in self.course_code_dict_name_to_index.items()}
        self.nb_of_students_per_course = None
        self.nb_of_students_per_course_code = None
        self.incompatible_courses_dict = None # a dictionnary of sets
        self.incompatible_courses_array = None 
        self.ordered_courses_for_student = None



    def fill_matrix(self):
        """
        Creates a binary matrix indicating which students are enrolled in which courses.

        Returns:
        - None
        """
        # Create a binary matrix S
        S = np.zeros((len(self.student_ids), len(self.course_codes)), dtype=int)

        # Fill the matrix with 1s where a student follows a course
        for j, course_code in enumerate(self.course_codes):
            for i, student_id in enumerate(self.student_ids):
                if student_id in self.data[course_code]:
                    S[i, j] = 1       
        self.matrix = S

        self.nb_of_students_per_course = np.sum(self.matrix, axis=0)
        dict_nb_of_students_per_course_code = {}
        for i in range(len(self.nb_of_students_per_course)):
            dict_nb_of_students_per_course_code[self.course_codes[i]] = self.nb_of_students_per_course[i]

        self.nb_of_students_per_course_code = dict_nb_of_students_per_course_code

    def fill_df(self):
        """
        Creates a DataFrame indicating which courses each student is enrolled in.

        Returns:
        - None
        """
        # Create a dictionary of enrollment data
        enrollment_data = {}
        for course, student_ids in self.data.items():
            for student_id in student_ids:
                if student_id not in enrollment_data:
                    enrollment_data[student_id] = {}
                enrollment_data[student_id][course] = 1

        # Convert the dictionary to a DataFrame
        df = pd.DataFrame.from_dict(enrollment_data, orient='index')
        df.fillna(0, inplace=True)
        self.df = df


    def fill_incompatible_dict(self):

        # create a dictionary to store the schedule of each course
        schedule_dict = {}

        # loop through each row in the data set
        for i, row in self.events.iterrows():
            # extract the course code from the current row
            course = row['Event']

            # add the current event to the schedule set
            start = row['Start']
            end = row['End']

            # add the schedule set to the dictionary
            if course in schedule_dict:
                schedule_dict[course] = [start,end]
                print("The same course was given twice in the same day")
            else:
                schedule_dict[course] = {"Start" : start, "End" :end}
        
        # now that we have the start and end time of each course, we can compute the ones which overlap
        intersection_dict = {}
        for course1,val1 in schedule_dict.items():
            intersection_set = set()
            for course2, val2 in schedule_dict.items():
                if course1 != course2:
                    # get the intersection of the schedules for the two courses
                    if overlap(val1,val2):
                        intersection_set.add(course2)
            # add the intersection set to the dictionary
            intersection_dict[course1] = intersection_set

        self.incompatible_courses = intersection_dict

        self.incompatible_courses_dict = intersection_dict
        # let's fill the array form as well since it'll be useful for the formulation
        intersection_list = []
        sorted_intersection_dict = dict(sorted(intersection_dict.items()))
        for key,val in sorted_intersection_dict.items():
            sub_list = []
            for course in val : 
                id = self.course_code_dict_name_to_index[course]
                sub_list.append(id)
            intersection_list.append(sub_list)
        
        self.incompatible_courses_array = intersection_list

    def fill_ordered_courses_for_student(self):
        ordered_courses = []
        # Find the courses followed by each student :
        mat = self.matrix
        for i in range(mat.shape[0]):
            courses_index = np.argwhere(mat[i,:]==1).flatten()
            #order the course by the start time of events
            sorted_courses_indexes = sorted(courses_index, key= lambda x : self.events.loc[x,"Start"])
            ordered_courses.append(sorted_courses_indexes)
        
        self.ordered_courses_for_student = ordered_courses

class Room():
    """
    A class representing a collection of classrooms and their distances.
    """
    
    def __init__(self, classrooms_path: str, distances_path: str, capacity_multiplier : float):
        """
        Initializes the Room object by reading classroom and distance data from CSV and Excel files.
        
        :param classrooms_path: A string representing the file path to the CSV file containing classroom data.
        :param distances_path: A string representing the file path to the Excel file containing distance data.
        """
        
        self.classrooms_path = classrooms_path
        self.distances_path = distances_path
        
        # Read classroom data from CSV file
        self.classrooms_data = pd.read_csv(self.classrooms_path, sep=';')
        
        # Read distance data from Excel file and set the first column as the index
        self.distances_data = pd.read_excel(self.distances_path)
        self.distances_data.set_index('Unnamed: 0', inplace=True)
        
        # Create a dictionary mapping classroom names to their corresponding index in classrooms_data
        self.name_to_index = {}
        for i, row in self.classrooms_data.iterrows():
            self.name_to_index[row['Name']] = i
            
        # Create a dictionary mapping classroom indices to their corresponding name
        self.index_to_name = {v: k for k, v in self.name_to_index.items()}
        
        # Initialize a variable to hold the distance matrix
        self.distance_matrix = None

        # Store the capacity of each room 
        self.capacity = {}
        for i, row in self.classrooms_data.iterrows():
            self.capacity[row['Name']] = row['Capacity']*capacity_multiplier
        self.capacities = np.array(self.classrooms_data["Capacity"])*capacity_multiplier
    
    def fill_matrix(self):
        """
        Fills the distance_matrix attribute with distances between classrooms.
        """
        
        # Initialize a 2D array of zeros with dimensions equal to the number of classrooms
        distance_matrix = np.zeros((len(self.classrooms_data),len(self.classrooms_data)))
        
        # Populate the distance matrix with distances between each pair of classrooms
        for i, row_i in self.classrooms_data.iterrows():
            i_build = row_i["Name"][0]
            for j, row_j in self.classrooms_data.iterrows():
                j_build = row_j["Name"][0]
                distance_matrix[i,j] = self.distances_data.loc[i_build,j_build]
        
        # Assign the filled distance matrix to the distance_matrix attribute
        self.distance_matrix = distance_matrix

