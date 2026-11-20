using Microsoft.EntityFrameworkCore;

namespace CampusConnect.Api;

/// <summary>
/// Explicit, destructive demo reset: deletes every complaint (with its timeline, feedback, support
/// and notifications) and replaces them with a realistic, believable data set. User accounts are kept.
/// Run with: dotnet CampusConnect.Api.dll --reset-demo   (needs SEED_PASSWORD and CONFIRM_RESET).
/// </summary>
public static class DemoData
{
    public const string Confirmation = "delete-all-complaints";

    public static void RequireConfirmation(IConfiguration configuration)
    {
        if (configuration["CONFIRM_RESET"] != Confirmation)
            throw new InvalidOperationException($"--reset-demo deletes every complaint. Set CONFIRM_RESET={Confirmation} to confirm.");
    }

    // Display names for the demo logins (emails and passwords are unchanged) and extra students.
    private static readonly (string Key, string Name, string? StudentId)[] Students =
    [
        ("student", "Ayesha Khan", "2024-ARID-1001"),
        ("student2", "Bilal Ahmed", "2024-ARID-1002"),
        ("sara", "Sara Malik", "2024-ARID-1003"),
        ("usman", "Usman Tariq", "2023-ARID-2004"),
        ("hina", "Hina Raza", "2023-ARID-2005"),
        ("zain", "Zain Abbas", "2025-ARID-3006"),
    ];
    private static readonly (string Key, string Name)[] Staff =
    [
        ("super", "Campus Administration"),
        ("cafeteria", "Cafeteria Office"),
        ("library", "Library Desk"),
        ("labit", "Labs & IT Support"),
        ("academic", "Academic Affairs"),
    ];

    private static string AuthorId(string who) => who switch
    {
        "Ayesha" => "user-student", "Bilal" => "user-student2", "Sara" => "user-sara",
        "Usman" => "user-usman", "Hina" => "user-hina", _ => "user-zain"
    };
    private static string AdminId(string categoryKey) => categoryKey switch
    {
        "CAFETERIA" => "user-cafeteria", "LIBRARY" => "user-library", "LAB_IT" => "user-labit", _ => "user-academic"
    };

    private sealed record E(string Cat, int Issue, string Title, string Desc, string? Loc, string Prio, string Status,
        double Ago, string Who, bool Anon = false, string? Work = null, string? Update = null, string? Done = null,
        int Rating = 0, string? Comment = null);

    private static readonly E[] Entries =
    [
        // ---- Cafeteria ----
        new("CAFETERIA", 0, "Stale samosas served at lunch", "The samosas at the main counter were cold and tasted stale around 1 pm. Several students in the queue returned theirs.", "Main cafeteria, counter 2", "HIGH", "RESOLVED", 18, "Ayesha",
            Work: "Kitchen supervisor informed and the morning batch was removed from the counter.", Done: "Counter staff retrained on hold times. Samosas are now fried in small batches every 45 minutes and the hygiene check is logged daily.", Rating: 5, Comment: "Much better now, thank you!"),
        new("CAFETERIA", 0, "Water dispenser near the entrance is dirty", "The drip tray and nozzle of the water dispenser at the cafeteria entrance are visibly dirty and there is a bad smell.", "Cafeteria entrance", "MEDIUM", "RESOLVED", 31, "Sara",
            Work: "Maintenance team assigned.", Done: "Dispenser deep-cleaned and added to the weekly cleaning checklist.", Rating: 4, Comment: "Clean again. Please keep checking it."),
        new("CAFETERIA", 1, "Fried rice price raised without notice", "The price of a plate of fried rice went up by Rs. 40 this week and there was no notice on the menu board.", "Main cafeteria", "MEDIUM", "REJECTED", 25, "Bilal",
            Done: "Prices follow the contractor's approved rate list, which was revised on 1 November. A notice board will now display the date of every price change."),
        new("CAFETERIA", 2, "Same menu for two weeks", "The daily menu has repeated almost unchanged for two weeks. Please add more variety, especially on Wednesdays and Thursdays.", "Main cafeteria", "LOW", "IN_PROGRESS", 9, "Hina",
            Work: "Raised with the contractor. A rotating weekly menu proposal has been requested."),
        new("CAFETERIA", 3, "Rude behaviour at the billing counter", "The cashier was dismissive and raised his voice when I asked about a wrong bill. This is not the first time.", "Billing counter", "MEDIUM", "PENDING", 1.2, "Usman", Anon: true),
        new("CAFETERIA", 0, "Flies around the dessert counter", "There are many flies around the dessert and sweet counter in the afternoon. The food stays uncovered.", "Dessert counter", "HIGH", "IN_PROGRESS", 2.1, "Zain",
            Work: "Pest control scheduled for tonight.", Update: "Pest control done. All desserts will be kept in covered display cases from tomorrow."),
        new("CAFETERIA", 2, "No vegetarian option after 2 pm", "After 2 pm only chicken dishes are left. Vegetarian students have nothing to eat in the late afternoon.", "Main cafeteria", "MEDIUM", "PENDING", 3.5, "Ayesha"),
        new("CAFETERIA", 0, "Tea served lukewarm", "The tea at the evening counter is lukewarm and thin. It looks like it was prepared long before serving.", "Tea counter", "LOW", "RESOLVED", 40, "Sara",
            Work: "Shared with the counter supervisor.", Done: "A second kettle was added at the counter so tea is brewed fresh every 30 minutes.", Rating: 3, Comment: "Better, but still slow at peak hours."),
        new("CAFETERIA", 3, "Long queue with only one billing counter", "At 1 pm there is a queue of 30 students and only one counter is open. Many students miss the start of their next class.", "Billing counter", "MEDIUM", "RESOLVED", 12, "Bilal",
            Work: "Reviewing counter staffing for peak hours.", Done: "A second billing counter now opens from 12:30 to 2:00 pm.", Rating: 4, Comment: "Queue moves much faster."),
        new("CAFETERIA", 0, "Serving spoons look unclean", "The shared serving spoons at the salad bar had dried food on them. Please change them more often.", "Salad bar", "MEDIUM", "RESOLVED", 52, "Hina",
            Done: "Spoons are now replaced every hour and washed in the kitchen between uses.", Rating: 5, Comment: "Thanks for the quick action."),
        new("CAFETERIA", 1, "Juice price higher than the posted menu", "I was charged Rs. 180 for a mango juice but the menu board says Rs. 150.", "Juice corner", "HIGH", "IN_PROGRESS", 6, "Zain",
            Work: "Comparing billed prices with the posted menu this week."),

        // ---- Library ----
        new("LIBRARY", 0, "Need updated Data Structures textbooks", "The Data Structures books on the shelf are from 2012. The current syllabus uses the latest edition, and there are not enough copies.", "Reading hall, shelf CS-4", "MEDIUM", "RESOLVED", 22, "Ayesha",
            Work: "Request forwarded to the acquisitions committee.", Done: "Three copies of the latest edition were ordered and are now on shelf CS-4.", Rating: 5, Comment: "Found the new edition today."),
        new("LIBRARY", 2, "Library closes at 4 pm during exams", "During exam weeks the library closes at 4 pm, when students most need a quiet place to study. Please extend the hours.", "Library main desk", "MEDIUM", "IN_PROGRESS", 5, "Usman",
            Work: "A proposal for extended exam-week hours has been sent to the registrar."),
        new("LIBRARY", 3, "Not enough seats near power sockets", "Only a few seats have a socket nearby, so most students cannot charge their laptops while studying.", "First floor reading area", "MEDIUM", "PENDING", 2.6, "Sara"),
        new("LIBRARY", 3, "Reading room is too noisy", "Groups talk loudly in the silent reading room and nobody asks them to stop.", "Silent reading room", "MEDIUM", "RESOLVED", 16, "Zain",
            Work: "Library staff briefed.", Done: "Silence signs were added and a staff member now patrols the room every hour.", Rating: 4, Comment: "Much quieter, thanks."),
        new("LIBRARY", 1, "Nobody at the issue desk", "I waited 25 minutes at the issue desk around noon and no librarian was available to issue my book.", "Issue desk", "MEDIUM", "REJECTED", 28, "Bilal",
            Done: "The desk was closed for a stocktake that was announced on the notice board. Normal service resumed the next morning."),
        new("LIBRARY", 0, "Journal database access not working", "I cannot log in to the online journal database from the campus network. It worked last month.", "Digital library", "HIGH", "RESOLVED", 8, "Hina",
            Work: "Checking the subscription login with the IT team.", Done: "The subscription login was restored and access was confirmed from the campus network.", Rating: 5, Comment: "Works again, thank you."),
        new("LIBRARY", 3, "Old magazines piled on reading tables", "Stacks of old magazines are left on the reading tables, so there is less room to study.", "Reading hall", "LOW", "RESOLVED", 35, "Ayesha",
            Done: "Magazines moved to the display rack and the tables are cleared every evening.", Rating: 4, Comment: "Tables are clear now."),
        new("LIBRARY", 2, "Request: open on Saturdays", "Many of us commute and can only study on Saturdays. Could the library open for half a day on Saturdays?", "Library main desk", "LOW", "PENDING", 4.8, "Usman", Anon: true),
        new("LIBRARY", 0, "Missing pages in the Circuit Analysis book", "Pages 112 to 130 are missing from the only Circuit Analysis book on the shelf.", "Engineering shelf E-2", "MEDIUM", "IN_PROGRESS", 3, "Sara",
            Work: "The book was withdrawn from the shelf and a replacement is being sourced."),
        new("LIBRARY", 3, "Air conditioning too cold in the reading hall", "The reading hall is freezing in the afternoon. It is hard to concentrate.", "Reading hall", "LOW", "RESOLVED", 45, "Zain",
            Done: "Thermostat adjusted to 24 degrees.", Rating: 3, Comment: "Comfortable now."),

        // ---- Labs & IT ----
        new("LAB_IT", 1, "Internet is down in Lab 2", "There has been no internet in Computer Lab 2 since morning. We cannot do our practical.", "Computer Lab 2", "HIGH", "RESOLVED", 11, "Ayesha",
            Work: "The network team is checking the lab switch.", Done: "The faulty switch was replaced and the connection has been stable for 24 hours.", Rating: 5, Comment: "Fixed within a day."),
        new("LAB_IT", 1, "Wi-Fi keeps dropping in the CS block", "The Wi-Fi disconnects every few minutes on the second floor of the CS block.", "CS block, second floor", "MEDIUM", "IN_PROGRESS", 4, "Bilal",
            Work: "Access point firmware update scheduled.", Update: "Firmware updated on 3 of 5 access points. The rest are due tomorrow."),
        new("LAB_IT", 2, "Projector in Room 204 shows no signal", "The projector in Room 204 says no signal when the laptop is connected. The lecture could not start.", "Room 204", "HIGH", "RESOLVED", 7, "Hina",
            Work: "Technician on the way.", Done: "HDMI cable replaced and projector input reset.", Rating: 5, Comment: "Fixed the same day."),
        new("LAB_IT", 2, "Projector flickers during lectures", "The projector in the seminar hall flickers every few minutes and gives me a headache.", "Seminar hall", "MEDIUM", "PENDING", 0.8, "Sara"),
        new("LAB_IT", 0, "Five PCs not booting in Lab 1", "Five computers in Lab 1 do not start at all. The lab is overcrowded because of this.", "Computer Lab 1", "HIGH", "IN_PROGRESS", 3.3, "Zain",
            Work: "Hardware team inspecting the power supplies."),
        new("LAB_IT", 0, "Keyboard keys missing on lab computers", "Several keyboards in Lab 3 have missing keys, which makes typing difficult.", "Computer Lab 3", "LOW", "RESOLVED", 33, "Usman",
            Done: "Eight keyboards replaced.", Rating: 4, Comment: "Thank you."),
        new("LAB_IT", 3, "MATLAB not installed on lab machines", "We need MATLAB for the Signals and Systems lab, but it is not installed on the Lab 3 computers.", "Computer Lab 3", "MEDIUM", "RESOLVED", 20, "Ayesha",
            Work: "Installation approved.", Done: "MATLAB 2024 was installed on all Lab 3 machines.", Rating: 5, Comment: "Works perfectly."),
        new("LAB_IT", 3, "Visual Studio licence expired", "Visual Studio asks for a licence on all the lab computers and we cannot build our projects.", "Computer Lab 1", "HIGH", "RESOLVED", 14, "Bilal",
            Work: "Contacting the vendor.", Done: "The institutional licence was renewed and activated on all machines.", Rating: 4, Comment: "Good, but it took two days."),
        new("LAB_IT", 1, "Slow internet during assignment deadlines", "The internet becomes extremely slow on deadline nights, so uploads to the portal fail.", "Hostel and library", "MEDIUM", "REJECTED", 26, "Hina",
            Done: "Bandwidth is shared across the whole campus. A bandwidth upgrade is planned for next semester and is tracked separately."),
        new("LAB_IT", 0, "Mouse not working at seat 14", "The mouse at seat 14 in Lab 2 does not respond.", "Computer Lab 2", "LOW", "PENDING", 1.5, "Zain"),
        new("LAB_IT", 3, "Request: Python IDE on lab computers", "Please install a Python IDE such as PyCharm on the lab computers for the AI course.", "Computer Lab 3", "LOW", "IN_PROGRESS", 6, "Sara",
            Work: "Approved. Installation is planned with the next lab image update."),
        new("LAB_IT", 2, "Projector remote missing in Lab 4", "The projector remote in Lab 4 is missing, so the instructor cannot change the input.", "Computer Lab 4", "LOW", "RESOLVED", 50, "Usman",
            Done: "A new remote was supplied and is kept at the lab assistant's desk.", Rating: 5, Comment: "Great."),

        // ---- Teaching & Academic ----
        new("ACADEMIC", 0, "Lectures start 20 minutes late", "For the past three weeks the lecture has started about 20 minutes late, so we lose a large part of every class.", "Room 105", "MEDIUM", "RESOLVED", 15, "Ayesha", Anon: true,
            Work: "Shared with the course coordinator.", Done: "The coordinator spoke with the instructor. The timetable is now enforced and attendance is logged at the start of class.", Rating: 4, Comment: "Classes start on time now."),
        new("ACADEMIC", 1, "Lecture notes not uploaded for Week 6", "The notes for Week 6 of Database Systems are not on the portal and the quiz is next week.", "Student portal", "LOW", "RESOLVED", 24, "Bilal",
            Done: "Notes uploaded to the portal and the instructor reminded to post them weekly.", Rating: 5, Comment: "Got them, thanks."),
        new("ACADEMIC", 3, "Teacher not visible from the back rows", "The teacher stands behind the podium and students in the back rows cannot see the board.", "Room 112", "LOW", "PENDING", 0.4, "Sara"),
        new("ACADEMIC", 2, "Hard to follow the Operating Systems lectures", "The scheduling algorithms are explained very quickly without examples. Many of us are lost.", "Room 210", "MEDIUM", "IN_PROGRESS", 5.5, "Hina", Anon: true,
            Work: "Shared with the department head. An extra problem-solving session is being arranged."),
        new("ACADEMIC", 3, "Students talking loudly during class", "A group at the back talks during the whole lecture. It is distracting.", "Room 105", "LOW", "RESOLVED", 30, "Zain",
            Done: "A seating plan was introduced for this section.", Rating: 3, Comment: "Better than before."),
        new("ACADEMIC", 1, "Slides missing for Database Systems", "The slides for chapters 7 and 8 have not been shared yet.", "Student portal", "MEDIUM", "PENDING", 2.9, "Zain"),
        new("ACADEMIC", 0, "Instructor often arrives 15 minutes late", "The instructor of our Thursday class arrives about 15 minutes late almost every week.", "Room 301", "HIGH", "IN_PROGRESS", 3.6, "Usman", Anon: true,
            Work: "A meeting with the instructor and the coordinator is set for this week."),
        new("ACADEMIC", 2, "Unclear explanation of recursion", "Recursion was covered in one lecture without enough examples and I still do not understand it.", "Room 210", "LOW", "RESOLVED", 38, "Sara",
            Done: "A recorded extra tutorial on recursion was shared with the whole class.", Rating: 5, Comment: "Very helpful video."),
        new("ACADEMIC", 3, "Whiteboard markers not available in Room 112", "There are no markers in Room 112 and the instructor had to borrow some from another room.", "Room 112", "LOW", "RESOLVED", 10, "Bilal",
            Done: "Marker supply restocked and a spare set is kept at the department office.", Rating: 4, Comment: "Thanks."),
        new("ACADEMIC", 1, "Reference material for the exam is missing", "The reference notes announced for the midterm are not on the portal.", "Student portal", "MEDIUM", "RESOLVED", 19, "Hina",
            Work: "Checking with the instructor.", Done: "Past papers and reference notes were published to the portal.", Rating: 4, Comment: "Good, thank you."),
        new("ACADEMIC", 3, "Discipline during the lab-theory session", "The joint lab-theory session gets very noisy. It is hard to follow the instructions.", "Room 301", "LOW", "PENDING", 0.3, "Ayesha"),
    ];

    /// <summary>Builds the complaints (with timelines, feedback and notifications) in memory.</summary>
    public static (List<Complaint> Complaints, List<Notification> Notifications) Build(DateTime now)
    {
        var complaints = new List<Complaint>();
        var notifications = new List<Notification>();
        var ordered = Entries.Select((e, i) => (e, i)).OrderByDescending(x => x.e.Ago).ToList();
        var sequence = 0;
        foreach (var (e, i) in ordered)
        {
            sequence++;
            var category = Catalog.Categories.Single(c => c.Key == e.Cat);
            var author = AuthorId(e.Who);
            var admin = AdminId(e.Cat);
            var created = now.AddDays(-e.Ago).AddMinutes(-(i * 7 % 53));
            var doneAfter = e.Prio switch { "HIGH" => 14 + i % 6, "LOW" => 90 + i % 30, _ => 36 + i % 20 };
            var done = created.AddHours(doneAfter);
            if (done > now.AddMinutes(-20)) done = now.AddMinutes(-20);
            var start = created.AddHours(2 + i % 4);
            if (start >= done) start = created.AddTicks((done - created).Ticks / 2);
            var complaint = new Complaint
            {
                Sequence = sequence, Ticket = $"CC-{now.Year}-{sequence:D4}", AuthorId = author, DepartmentId = "dept-" + category.Slug,
                Category = e.Cat, SubIssue = category.Issues[e.Issue], Title = e.Title, Description = e.Desc, Location = e.Loc,
                Priority = e.Prio, Status = e.Status, AnonymousToStaff = e.Anon, CreatedAt = created, DueAt = Catalog.Due(created, e.Prio)
            };
            var last = created;
            void Add(string type, string actor, DateTime at, string? from, string? to, string? body)
            {
                complaint.Timeline.Add(new TimelineEntry { ActorId = actor, Type = type, FromStatus = from, ToStatus = to, Body = body, CreatedAt = at });
                last = at;
                if (type == "CREATED") return;
                var message = type == "REMARK" ? $"{complaint.Ticket}: {body}" : $"{complaint.Ticket}: {to}" + (body is null ? "" : $" — {body}");
                notifications.Add(new Notification { UserId = author, ComplaintId = complaint.Id, Message = message, CreatedAt = at, Read = at < now.AddHours(-36) });
            }
            Add("CREATED", author, created, null, "PENDING", null);
            if (e.Status == "REJECTED" && e.Work is null)
                Add("STATUS_CHANGE", admin, done, "PENDING", "REJECTED", e.Done);
            else if (e.Status != "PENDING")
            {
                Add("STATUS_CHANGE", admin, start, "PENDING", "IN_PROGRESS", e.Work);
                if (e.Update is not null)
                {
                    var at = e.Status == "IN_PROGRESS" ? start.AddHours(18) : start.AddTicks((done - start).Ticks / 2);
                    if (at >= now.AddMinutes(-10)) at = start.AddTicks((now.AddMinutes(-10) - start).Ticks / 2);
                    Add("REMARK", admin, at, null, null, e.Update);
                }
                if (e.Status is "RESOLVED" or "REJECTED")
                    Add("STATUS_CHANGE", admin, done, "IN_PROGRESS", e.Status, e.Done);
            }
            complaint.UpdatedAt = last;
            complaint.ResolvedAt = e.Status == "RESOLVED" ? last : null;
            if (e.Status == "RESOLVED" && e.Rating > 0) complaint.Feedback = new Feedback { Rating = e.Rating, Comment = e.Comment };
            complaints.Add(complaint);
        }
        return (complaints, notifications);
    }

    public static async Task Reset(AppDb db, string password)
    {
        Seed.RequirePassword(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["SEED_PASSWORD"] = password }).Build());
        Console.WriteLine($"Before: {await db.Complaints.CountAsync()} complaints, {await db.Notifications.CountAsync()} notifications, {await db.Users.CountAsync()} users.");
        await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);

        await db.Notifications.ExecuteDeleteAsync();
        await db.Feedback.ExecuteDeleteAsync();
        await db.Supports.ExecuteDeleteAsync();
        await db.Timeline.ExecuteDeleteAsync();
        await db.Complaints.ExecuteDeleteAsync();
        await db.TicketCounters.ExecuteDeleteAsync();

        // Departments must exist (the demo accounts and complaints point at them).
        foreach (var c in Catalog.Categories)
            if (!await db.Departments.AnyAsync(x => x.Slug == c.Slug))
                db.Departments.Add(new Department { Id = "dept-" + c.Slug, Name = c.Label + " Administration", Slug = c.Slug });
        await db.SaveChangesAsync();

        // Friendly names for the demo logins; new students get the shared demo password.
        var hash = BCrypt.Net.BCrypt.HashPassword(password, 10);
        foreach (var (key, name) in Staff)
        {
            var user = await db.Users.SingleOrDefaultAsync(x => x.Id == "user-" + key);
            if (user is not null) user.Name = name;
        }
        foreach (var (key, name, studentId) in Students)
        {
            var user = await db.Users.SingleOrDefaultAsync(x => x.Id == "user-" + key);
            if (user is null)
                db.Users.Add(new User { Id = "user-" + key, Name = name, Email = key + "@campusconnect.edu", PasswordHash = hash, Role = Roles.Student, StudentId = studentId });
            else { user.Name = name; user.StudentId ??= studentId; }
        }
        await db.SaveChangesAsync();

        var (complaints, notifications) = Build(DateTime.UtcNow);
        db.Complaints.AddRange(complaints);
        db.Notifications.AddRange(notifications);
        db.TicketCounters.Add(new TicketCounter { Year = DateTime.UtcNow.Year, Value = complaints.Count });
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        Console.WriteLine($"After: {complaints.Count} complaints, {notifications.Count} notifications.");
    }
}
