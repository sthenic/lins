import streams
import terminal
import strformat

include ../../src/lexers/plain_lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0


proc callback(s: Sentence) =
   response.add($s.str)


template run_test(title, stimuli: string; reference: seq[string]) =
   response = @[]
   lex(new_string_stream(stimuli), callback, 0, 0)
   try:
      for i in 0..<response.len:
         do_assert(response[i] == reference[i], "'" & response[i] & "'")
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   except AssertionError as e:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'", e.msg)
      nof_failed += 1
   except IndexError:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'", #resetStyle,
                      "(missing reference data)")
      nof_failed += 1

run_test("Golden rule 1",
   "Hello World. My name is Jonas.",
   @["Hello World.", "My name is Jonas."])

run_test("Golden rule 2",
   "What is your name? My name is Jonas.",
   @["What is your name?", "My name is Jonas."])

run_test("Golden rule 3",
   "There it is! I found it.",
   @["There it is!", "I found it."])

run_test("Golden rule 4",
   "My name is Jonas E. Smith.",
   @["My name is Jonas E. Smith."])

run_test("Golden rule 5",
   "Please turn to p. 55.",
   @["Please turn to p. 55."])

run_test("Golden rule 6",
   "Were Jane and co. at the party?",
   @["Were Jane and co. at the party?"])

run_test("Golden rule 7",
   "They closed the deal with Pitt, Briggs & Co. at noon.",
   @["They closed the deal with Pitt, Briggs & Co. at noon."])

run_test("Golden rule 8",
   "Let's ask Jane and co. They should know.",
   @["Let's ask Jane and co.", "They should know."])

run_test("Golden rule 9",
   "They closed the deal with Pitt, Briggs & Co. It closed yesterday.",
   @["They closed the deal with Pitt, Briggs & Co.", "It closed yesterday."])

run_test("Golden rule 10",
   "I can see Mt. Fuji from here.",
   @["I can see Mt. Fuji from here."])

run_test("Golden rule 11",
   "St. Michael's Church is on 5th st. near the light.",
   @["St. Michael's Church is on 5th st. near the light."])

run_test("Golden rule 12",
   "That is JFK Jr.'s book.",
   @["That is JFK Jr.'s book."])

run_test("Golden rule 13",
   "That is JFK Jr.'s book.",
   @["That is JFK Jr.'s book."])

run_test("Golden rule 14",
   "I visited the U.S.A. last year.",
   @["I visited the U.S.A. last year."])

run_test("Golden rule 15",
   "I live in the E.U. How about you?",
   @["I live in the E.U. How about you?"])

run_test("Golden rule 16",
   "I live in the U.S. How about you?",
   @["I live in the U.S. How about you?"])

run_test("Golden rule 17",
   "I have lived in the U.S. for 20 years.",
   @["I have lived in the U.S. for 20 years."])

run_test("Golden rule 18",
   "At 5 a.m. Mr. Smith went to the bank. He left the bank at 6 P.M. Mr. Smith then went to the store.",
   @["At 5 a.m. Mr. Smith went to the bank.", "He left the bank at 6 P.M. Mr. Smith then went to the store."])

run_test("Golden rule 19",
   "She has $100.00 in her bag.",
   @["She has $100.00 in her bag."])

run_test("Golden rule 20*",
   "She has $100.00. It is in her bag.",
   @["She has $100.00. It is in her bag."])

run_test("Golden rule 21",
   "He teaches science (He previously worked for 5 years as an engineer.) at the local University.",
   @["He teaches science (He previously worked for 5 years as an engineer.) at the local University."])

run_test("Golden rule 22",
   "Her email is Jane.Doe@example.com. I sent her an email.",
   @["Her email is Jane.Doe@example.com.", "I sent her an email."])

run_test("Golden rule 23",
   "The site is: https://www.example.50.com/new-site/awesome_content.html. Please check it out.",
   @["The site is: https://www.example.50.com/new-site/awesome_content.html.", "Please check it out."])

run_test("Golden rule 24",
   "She turned to him, 'This is great.' she said.",
   @["She turned to him, 'This is great.' she said."])

run_test("Golden rule 25",
   "She turned to him, \"This is great.\" she said.",
   @["She turned to him, \"This is great.\" she said."])

run_test("Golden rule 26",
   "She turned to him, \"This is great.\" She held the book out to show him.",
   @["She turned to him, \"This is great.\" She held the book out to show him."])

run_test("Golden rule 27",
   "Hello!! Long time no see.",
   @["Hello!!", "Long time no see."])

run_test("Golden rule 28",
   "Hello?? Who is there?",
   @["Hello??", "Who is there?"])

run_test("Golden rule 29",
   "Hello!? Is that you?",
   @["Hello!?", "Is that you?"])

run_test("Golden rule 30",
   "Hello?! Is that you?",
   @["Hello?!", "Is that you?"])

run_test("Golden rule 31",
   "1.) The first item 2.) The second item",
   @["1.) The first item 2.) The second item"])

run_test("Golden rule 32",
   "1.) The first item. 2.) The second item.",
   @["1.) The first item. 2.) The second item."])

run_test("Golden rule 33",
   "1) The first item 2) The second item",
   @["1) The first item 2) The second item"])

run_test("Golden rule 34",
   "1) The first item. 2) The second item.",
   @["1) The first item. 2) The second item."])

run_test("Golden rule 35",
   "1. The first item 2. The second item",
   @["1. The first item 2. The second item"])

run_test("Golden rule 36",
   "1. The first item. 2. The second item.",
   @["1. The first item. 2. The second item."])

run_test("Golden rule 37",
   "• 9. The first item • 10. The second item",
   @["• 9. The first item • 10. The second item"])

run_test("Golden rule 38",
   "⁃9. The first item ⁃10. The second item",
   @["⁃9. The first item ⁃10. The second item"])

run_test("Golden rule 39",
   "a. The first item b. The second item c. The third list item",
   @["a. The first item b. The second item c. The third list item"])

run_test("Golden Rule 40",
   "This is a sentence\ncut off in the middle because pdf.",
   @["This is a sentence cut off in the middle because pdf."])

run_test("Golden Rule 41a*",
   "It was a cold \nnight in the city.",
   @["It was a cold  night in the city."])

run_test("Golden Rule 41b*",
   "It was a cold\n night in the city.",
   @["It was a cold night in the city."])

run_test("Golden Rule 42*",
   "features\ncontact manager\nevents, activities\n",
   @["features contact manager events, activities"])

run_test("Golden Rule 43*",
   "You can find it at N°. 1026.253.553. That is where the treasure is.",
   @["You can find it at N°. 1026.253.553. That is where the treasure is."])

run_test("Golden Rule 44",
   "She works at Yahoo! in the accounting department.",
   @["She works at Yahoo! in the accounting department."])

run_test("Golden Rule 45*",
   "We make a good team, you and I. Did you see Albert I. Jones yesterday?",
   @["We make a good team, you and I. Did you see Albert I. Jones yesterday?"])

run_test("Golden rule 46",
   "Thoreau argues that by simplifying one’s life, “the laws of the universe will appear less complex. . . .”",
   @["Thoreau argues that by simplifying one’s life, “the laws of the universe will appear less complex. . . .”"])

run_test("Golden rule 47",
   "\"Bohr [...] used the analogy of parallel stairways [...]\" (Smith 55).",
   @["\"Bohr [...] used the analogy of parallel stairways [...]\" (Smith 55)."])

run_test("Golden rule 48*",
   "If words are left off at the end of a sentence, and that is all that is omitted, indicate the omission with ellipsis marks (preceded and followed by a space) and then indicate the end of the sentence with a period . . . . Next sentence.",
   @["If words are left off at the end of a sentence, and that is all that is omitted, indicate the omission with ellipsis marks (preceded and followed by a space) and then indicate the end of the sentence with a period . . . . Next sentence."])

run_test("Golden rule 49",
   "I never meant that.... She left the store.",
   @["I never meant that....", "She left the store."])

run_test("Golden rule 50a",
   "I wasn’t really ... well, what I mean...see  . . . what I'm saying, the thing is . . . I didn’t mean it.",
   @["I wasn’t really ... well, what I mean...see  . . . what I'm saying, the thing is . . . I didn’t mean it."])

run_test("Golden rule 50b", # Irregular spacing in ellipses.
   "I wasn’t really . .. well, what I mean...see  .  . . what I'm saying, the thing is .  .. . I didn’t mean it.",
   @["I wasn’t really . .. well, what I mean...see  .  . . what I'm saying, the thing is .  .. . I didn’t mean it."])

run_test("Golden rule 51",
   "One further habit which was somewhat weakened . . . was that of combining words into self-interpreting compounds. . . . The practice was not abandoned. . . .",
   @["One further habit which was somewhat weakened . . . was that of combining words into self-interpreting compounds. . . . The practice was not abandoned. . . ."])


# Print summary
styledWriteLine(stdout, styleBright, "\n----- SUMMARY -----")
var test_str = "test"
if nof_passed > 1:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_passed:<4} ", test_str,
                fgGreen, " PASSED")

test_str = "test"
if nof_failed > 1:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_failed:<4} ", test_str,
                fgRed, " FAILED")

styledWriteLine(stdout, styleBright, "-------------------")

quit(nof_failed)
