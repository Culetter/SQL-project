# GradeBook: Student Grades and Attendance Management System

This project is a SQL database system for managing student grades, attendance, and schedules.  
It was created as part of a database design project.

## Database

**Database name:** `GradeBook`

### Tables
- `Groups` – stores student groups/classes  
- `Status` – defines user roles (Student, Teacher, Administrator)  
- `Users` – stores user information (students, teachers, administrators)  
- `Students` – stores student-specific data such as group and album number  
- `Subjects` – stores subjects taught at the school  
- `Reasons` – reasons for absences (with or without justification)  
- `Absence` – stores attendance records for students  
- `Grades` – stores individual grades for students  
- `Schedule` – stores the weekly schedule for groups and teachers  
- `Final_Grades` – stores calculated semester grades  

### Triggers
- `trg_Final_Grade` – automatically calculates and updates final grades after inserting new grades

### Stored Procedures
- `AddUpdate` – adds or updates users, including student-specific data  
- `DeleteUser` – deletes users and all related records in grades, schedule, and attendance

### Sample Data
- Predefined groups, subjects, reasons, and statuses  
- Example users, students, teachers, and administrators  
- Sample grades, attendance, and schedules  

## How to Use

1. Create the database and tables using the provided SQL scripts.  
2. Insert initial data using the sample `INSERT` statements.  
3. Use the stored procedures `AddUpdate` and `DeleteUser` to manage users.  
4. Queries are provided to view grades, final grades, schedules, and absences.

## Example Queries
```sql
-- View all users and students
select * from Users
left join Students on Users.UserID = Students.StudentID;

-- View grades with teacher names
select GradeID, CONCAT(student.[Name], ' ', student.LastName) as Student, Subjects.[Name] as Subject, Grade, [Date], CONCAT(teacher.[Name], ' ', teacher.[LastName]) as Teacher 
from Grades
join Users student on Grades.StudentID = student.UserID
join Users teacher on Grades.TeacherID = teacher.UserID
join Subjects on Grades.SubjectID = Subjects.SubjectID;
