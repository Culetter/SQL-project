create database GradeBook
use GradeBook
drop database GradeBook

create table Groups(
GroupID int identity primary key,
[Name] varchar(15) not null unique
)

create table [Status](
StatusID int identity primary key,
[Name] varchar(13) not null unique
)

create table Users (
UserID int identity primary key,
[Name] varchar(10) not null,
LastName varchar(20) not null,
[Login] varchar(20) not null unique,
[Password] varchar(20) not null,
StatusID int not null,
Email varchar (50) unique,
Phone varchar(12) unique,
foreign key (StatusID) references [Status](StatusID)
)

create table Students(
StudentID int primary key,
GroupID int not null,
[Start_date] date not null,
[End_date] date not null,
AlbumNr int not null unique,
foreign key (GroupID) references Groups(GroupID),
foreign key (StudentID) references Users(UserID)
)


create table Subjects(
SubjectID int identity primary key,
[Name] varchar(30) not null unique
)

create table Reasons(
ReasonID int identity primary key,
[Name] varchar(20) not null unique
)

create table Absence(
AbsenceID int identity primary key,
StudentID int not null,
[Date] date not null,
SubjectID int not null,
ReasonID int not null,
TeacherID int,
foreign key (StudentID) references Users(UserID),
foreign key (TeacherID) references Users(UserID),
foreign key (ReasonID) references Reasons (ReasonID),
foreign key (SubjectID) references Subjects(SubjectID)
)

create table Grades(
GradeID int identity primary key,
StudentID int not null,
SubjectID int not null,
Grade float not null,
[Date] date not null,
TeacherID int,
foreign key (StudentID) references Users(UserID),
foreign key (TeacherID) references Users(UserID),
foreign key (SubjectID) references Subjects(SubjectID)
)

create table Schedule(
GroupID int not null,
SubjectID int not null,
TeacherID int not null,
[DayOfWeek] tinyint not null
foreign key (GroupID) references Groups(GroupID),
foreign key (SubjectID) references Subjects(SubjectID),
foreign key (TeacherID) references Users(UserID)
)

create table Final_Grades(
Final_GradeID int identity primary key,
Final_Grade float not null,
Semester tinyint not null,
StudentID int not null,
SubjectID int not null,
foreign key (StudentID) references Students(StudentID),
foreign key (SubjectID) references Subjects(SubjectID)
)

go
create trigger trg_Final_Grade
on Grades
after insert
as
begin
    declare @StartDate date
    declare @GradeDate date
    declare @Semester int
    declare @StudentID int
    declare @SubjectID int
    declare @FinalGrade float
	declare @Year int

    declare inserted_cursor cursor for
    select StudentID, [Date], SubjectID from inserted

    open inserted_cursor
    fetch next from inserted_cursor into @StudentID, @GradeDate, @SubjectID

    while @@FETCH_STATUS = 0
    begin
	    select @StartDate = [Start_date] 
        from Students 
        where StudentID = @StudentID

		set @Year = year(@GradeDate) - year(@StartDate)
		if month(@GradeDate) < 9
		begin 
			set @Year = @Year - 1
		end
		set @Year = @Year + 1

        if MONTH(@GradeDate) between 9 and 12
        begin
            set @Semester = (@Year - 1) * 2 + 1
            
            select @FinalGrade = AVG(Grade)
            from Grades
            where YEAR([Date]) = YEAR(@GradeDate) and MONTH([Date]) >= 9 and StudentID = @StudentID;
        end
        else if MONTH(@GradeDate) between 2 and 7
        begin
            set @Semester = (@Year - 1) * 2 + 2
            
            select @FinalGrade = AVG(Grade)
            from Grades
            where YEAR([Date]) = YEAR(@GradeDate) and MONTH([Date]) <= 6 and StudentID = @StudentID;
        end
		else 
		begin
			return
		end

        if exists (
            select 1 
            from Final_Grades 
            where StudentID = @StudentID and SubjectID = @SubjectID and Semester = @Semester
        )
        begin
            update Final_Grades
            set Final_Grade = @FinalGrade
            where StudentID = @StudentID and SubjectID = @SubjectID and Semester = @Semester;
        end
        else
        begin
            insert into Final_Grades (Final_Grade, Semester, StudentID, SubjectID)
            values (@FinalGrade, @Semester, @StudentID, @SubjectID);
        end

        fetch next from inserted_cursor into @StudentID, @GradeDate, @SubjectID
    end

    close inserted_cursor
    deallocate inserted_cursor
end

go
create procedure AddUpdate
@UserId int = null,
@Name varchar(10),
@LastName varchar(20),
@Login varchar(20),
@Password varchar(20),
@StatusID int,
@Email varchar(50) = null,
@Phone varchar(12) = null,
@GroupID int = null,
@StartDate date = null,
@EndDate date = null,
@AlbumNr int = null
as
begin
	declare @CurrentStatusID int;
	select @CurrentStatusID = StatusID from Users where UserID = @UserId;

	if (@StatusID = 1 and @CurrentStatusID in (2, 3)) or (@StatusID in (2, 3) and @CurrentStatusID = 1)
	begin
		print 'You cannot upgrade a student to a teacher or administrator and vice versa'
		return
	end
	if @StatusID = 1 and (@GroupID is null or @StartDate is null or @EndDate is null or @AlbumNr is null or @EndDate <= @StartDate)
    begin
        print 'Incorrect data entered'
        return
    end
    if @UserId is not null
    begin
        if exists (select 1 from Users where UserID = @UserId)
        begin
            update Users
            set 
                [Name] = @Name,
                LastName = @LastName,
				[Login] = @Login,
				[Password] = @Password,
				StatusID = @StatusID,
				Email = @Email,
				Phone = @Phone
            where UserID = @UserId;
			if @StatusID = 1
			begin
				update Students
				set
					GroupID = @GroupID,
					[Start_date] = @StartDate,
					End_date = @EndDate,
					AlbumNr = @AlbumNr
				where StudentID = @UserId
			end
        end
        else
        begin
            print 'There is no such user'
        end
    end
    else
    begin
        insert into Users ([Name], LastName, [Login], [Password], StatusID, Email, Phone) values
		(@Name, @LastName, @Login, @Password, @StatusID, @Email, @Phone)

		if @StatusID = 1
		begin
			insert into Students (StudentID, GroupID, [Start_date], End_date, AlbumNr) values
			((select UserID from Users where [Login] = @Login), @GroupID, @StartDate, @EndDate, @AlbumNr)
		end
    end
end

go
create procedure DeleteUser
@UserID int
as
begin
	declare @UserStatus int
	select @UserStatus = StatusID from Users where UserID = @UserID
	if @UserStatus = 1
	begin
		delete from Final_Grades where StudentID = @UserID
		delete from Students where StudentID = @UserID
	end
	else
	begin
		delete from Schedule where TeacherID = @UserID
		update Grades set TeacherID = NULL where TeacherID = @UserID
		update Absence set TeacherID = NULL where TeacherID = @UserID
	end
	delete from Users where UserID = @UserID
end

insert into [Status]([Name]) values 
('Student'),
('Tracher'),
('Administrator')

insert into Groups([Name]) values
('Group 1 PL'),
('Group 2 PL'),
('Group 3 PL'),
('Group 4 PL'),
('Group 5 PL'),
('Group 6 PL'),
('Group 1 EN'),
('Group 2 EN'),
('Group 3 EN'),
('Group 4 EN')

insert into Subjects([Name]) values
('Algorithms and Data Structures'),
('Computer Networks'),
('Artificial Intelligence'),
('Cybersecurity Fundamentals'),
('Operating Systems'),
('Software Engineering'),
('Database Management Systems'),
('Machine Learning'),
('Web Development'),
('Human-Computer Interaction')

insert into Reasons([Name]) values
('With reason'),
('Without reason')

EXEC AddUpdate NULL, 'Nazarii', 'Lozynskyi', 'nLozynskyi30', '4037Ug$2', 1, 'nlozyns1@stu.vistula.edu.pl', '+48521127352', 1, '2024-09-01', '2029-07-01', 72102
EXEC AddUpdate NULL, 'Andriy', 'Shevchenko', 'ashevchenko', 'Pa$$w0rd1', 1, 'ashev@uni.edu', '+48123123123', 2, '2024-09-01', '2028-07-01', 72103;
EXEC AddUpdate NULL, 'Oksana', 'Petryk', 'opetryk', 'SeCuRe#45', 1, 'opetryk@uni.edu', '+48765432109', 3, '2024-09-01', '2029-06-30', 72104;
EXEC AddUpdate NULL, 'Maksym', 'Kovalenko', 'mkovalenko', 'MaxPass99!', 1, 'mkovalenko@uni.edu', '+48222333444', 4, '2023-09-01', '2027-07-01', 72105;
EXEC AddUpdate NULL, 'Iryna', 'Melnyk', 'imelnyk', 'IrinaSafe77$', 1, 'imelnyk@uni.edu', '+48987654321', 5, '2025-09-01', '2030-07-01', 72106;
EXEC AddUpdate NULL, 'Taras', 'Hrytsenko', 'thrytsenko', 'Tr@ssWord34', 1, 'thrytsenko@uni.edu', '+48567890123', 6, '2022-09-01', '2026-07-01', 72107;
EXEC AddUpdate NULL, 'Olena', 'Dovzhenko', 'odovzhenko', 'OlenaPass22!', 1, 'odovzhenko@uni.edu', '+48654321987', 7, '2024-09-01', '2029-07-01', 72108;
EXEC AddUpdate NULL, 'Roman', 'Shapoval', 'rshapoval', 'Rom@n2024$', 1, 'rshapoval@uni.edu', '+48111222333', 8, '2023-09-01', '2028-07-01', 72109;
EXEC AddUpdate NULL, 'Anastasiia', 'Zhuk', 'azhuk', 'Nastia!999', 1, 'azhuk@uni.edu', '+48789213456', 9, '2024-09-01', '2029-07-01', 72110;
EXEC AddUpdate NULL, 'Yaroslav', 'Bondarenko', 'ybondarenko', 'YaB#1245!', 1, 'ybondarenko@uni.edu', '+48234567890', 10, '2024-09-01', '2029-07-01', 72111;
EXEC AddUpdate NULL, 'Dmytro', 'Lysenko', 'dlysenko', 'Dmytr0_!23', 2, 'dlysenko@uni.edu', '+48876543210';
EXEC AddUpdate NULL, 'Sofia', 'Kravchenko', 'skravchenko', 'S0fiaPass!', 3, 'skravchenko@uni.edu', '+48901234567';

insert into Schedule(GroupID, SubjectID, TeacherID, [DayOfWeek]) values
(1, 1, 11, 1),
(1, 1, 11, 4),

(3, 2, 11, 2),
(3, 2, 11, 5),

(5, 3, 11, 1),
(5, 3, 11, 4),

(7, 4, 11, 5),
(7, 4, 11, 2),

(9, 5, 11, 1),
(9, 5, 11, 3),

(2, 6, 12, 3),
(2, 6, 12, 4),

(4, 7, 12, 4),
(4, 7, 12, 3),

(6, 8, 12, 2),
(6, 8, 12, 1),

(8, 9, 12, 1),
(8, 9, 12, 4),

(10, 10, 12, 1),
(10, 10, 12, 5)

insert into Grades(StudentID, SubjectID, Grade, [Date], TeacherID) values
(1, 1, 5, '2024-9-23', 11),
(1, 1, 4, '2024-11-03', 11),
(1, 1, 4, '2025-03-15', 11),
(1, 1, 3, '2025-05-24', 11),

(2, 2, 4, '2025-9-23', 12),
(2, 2, 4, '2025-11-03', 12),
(2, 2, 5, '2025-03-15', 12),
(2, 2, 3, '2025-05-24', 12),

(3, 3, 4, '2024-10-15', 11),
(3, 3, 2, '2024-12-05', 11),
(3, 3, 5, '2025-03-10', 11),
(3, 3, 1, '2025-06-20', 11),

(4, 4, 0, '2023-10-10', 12),
(4, 4, 3, '2023-12-01', 12),
(4, 4, 2, '2024-03-15', 12),
(4, 4, 4, '2024-06-05', 12),

(5, 5, 5, '2029-03-01', 11),
(5, 5, 1, '2029-06-30', 11),
(5, 5, 0, '2030-05-02', 11),
(5, 5, 3, '2030-03-18', 11),

(6, 6, 2, '2024-02-15', 12),
(6, 6, 4, '2024-06-25', 12),
(6, 6, 1, '2025-10-10', 12),
(6, 6, 5, '2025-12-20', 12),

(7, 7, 3, '2024-10-05', 11),
(7, 7, 0, '2024-12-10', 11),
(7, 7, 2, '2025-02-20', 11),
(7, 7, 4, '2025-06-15', 11),

(8, 8, 5, '2024-03-10', 12),
(8, 8, 3, '2024-06-28', 12),
(8, 8, 4, '2025-10-01', 12),
(8, 8, 1, '2025-12-22', 12),

(9, 9, 2, '2024-10-25', 11),
(9, 9, 4, '2024-12-15', 11),
(9, 9, 0, '2025-02-28', 11),
(9, 9, 5, '2025-06-10', 11),

(10, 10, 3, '2024-10-05', 12),
(10, 10, 5, '2024-12-20', 12),
(10, 10, 1, '2025-03-05', 12),
(10, 10, 2, '2025-06-30', 12)

insert into Absence(StudentID, [Date], SubjectID, ReasonID, TeacherID) values
(7, '2024-02-15', 3, 1, 11),
(2, '2024-01-22', 6, 2, 12),
(9, '2024-02-01', 1, 1, 11),
(5, '2024-01-10', 8, 2, 12),
(3, '2024-02-05', 4, 1, 11),
(10, '2024-01-18', 7, 2, 12),
(1, '2024-02-10', 5, 1, 11),
(6, '2024-01-30', 2, 2, 12),
(4, '2024-02-07', 9, 1, 11),
(8, '2024-01-25', 10, 2, 12);


select * from [Status]
select * from Groups
select * from Subjects
select * from Reasons

select * from Users
left join Students on Users.UserID = Students.StudentID

select * from Grades

select Groups.[Name] as [Group], Subjects.[Name] as [Subject], concat(Users.[Name], ' ', Users.LastName) as Teacher, DATENAME(WEEKDAY, DATEADD(DAY, [DayOfWeek] - 1, '19000101')) AS [Day] from Schedule
join Groups on Schedule.GroupID = Groups.GroupID
join Subjects on Schedule.SubjectID = Subjects.SubjectID
join Users on Schedule.TeacherID = Users.UserID

select GradeID, CONCAT(student.[Name], ' ', student.LastName) as Student, Subjects.[Name] as Subject, Grade, [Date], CONCAT(teacher.[Name], ' ', teacher.[LastName]) as Teacher from Grades
join Users student on Grades.StudentID = student.UserID
join Users teacher on Grades.TeacherID = teacher.UserID
join Subjects on Grades.SubjectID = Subjects.SubjectID

select Final_GradeID, Final_Grade, Semester, concat(Users.[Name], ' ', Users.LastName) as Student, Subjects.[Name] as [Subject] from Final_Grades
join Users on Final_Grades.StudentID = Users.UserID
join Subjects on Final_Grades.SubjectID = Subjects.SubjectID

select AbsenceID, CONCAT(student.[Name], ' ', student.LastName) as Student, [Date], Subjects.[Name] as [Subject], Reasons.[Name] as Reason, CONCAT(teacher.[Name], ' ', teacher.[LastName]) as Teacher from Absence
join Users student on Absence.StudentID = student.UserID
join Users teacher on Absence.TeacherID = teacher.UserID
join Subjects on Absence.SubjectID = Subjects.SubjectID
join Reasons on Reasons.ReasonID = Absence.ReasonID

EXEC AddUpdate 1, 'Nazarii', 'Lozynskyi', 'nLozynskyi30', '4037Ug$2', 1, 'nlozyns1@uni.edu', '+48521127352', 1, '2024-09-01', '2029-07-01', 72102

EXEC DeleteUser 12