class_name PracticeBank
extends RefCounted
## Offline practice questions for runs without a server ticket (coins are not saved).
## `build` returns `count` explained questions (runs use 20–50).
## Starter items are adapted from web/starter.json (original Study Arena content, CC BY 4.0).
## The remaining explained questions are original Study Arena practice content (CC BY 4.0).

const ITEMS := [
	["Algebra", "Solve 3x = 12.", ["2", "3", "4", "6"], 2, "Divide both sides by 3: x = 12 ÷ 3 = 4."],
	["Algebra", "The slope of y = 2x + 5 is 5.", ["True", "False"], 1, "The coefficient of x is the slope, so it is 2."],
	["Algebra", "Solve x + 7 = 10.", ["3", "7", "10", "17"], 0, "Subtract 7 from both sides: x = 3."],
	["Calculus", "What is the derivative of x²?", ["x", "2x", "2", "x³"], 1, "The power rule gives d(xⁿ)/dx = nxⁿ⁻¹."],
	["Calculus", "The derivative of a constant is zero.", ["True", "False"], 0, "A constant has no change, so its rate of change is zero."],
	["Calculus", "For f(x) = 3x², what is f′(2)?", ["6", "12", "18", "24"], 1, "f′(x) = 6x, and 6 × 2 = 12."],
	["Computing", "Convert binary 101 to decimal.", ["3", "4", "5", "6"], 2, "The place values are 4, 2 and 1: 4 + 0 + 1 = 5."],
	["Computing", "An algorithm is a finite sequence of steps.", ["True", "False"], 0, "Algorithms specify ordered steps that terminate for their intended inputs."],
	["Computing", "A single loop over n items has which complexity?", ["O(1)", "O(log n)", "O(n)", "O(n²)"], 2, "Work grows proportionally with n, so it is O(n)."],
	["Calculus", "What does a derivative measure?", ["Total area", "Instantaneous rate of change", "Average value", "The y-intercept"], 1, "A derivative is the instantaneous rate of change of a function."],
	["Algebra", "In y = mx + b, what does b represent?", ["Slope", "y-intercept", "x-intercept", "Domain"], 1, "b is the value of y when x = 0, the y-intercept."],
	["Algebra", "Solve 2x − 4 = 10.", ["3", "5", "7", "14"], 2, "Add 4 to get 2x = 14, then divide by 2: x = 7."],
	["Algebra", "Expand (x + 3)(x + 2).", ["x² + 5x + 6", "x² + 6x + 5", "x² + 6", "2x + 5"], 0, "FOIL: x² + 2x + 3x + 6 = x² + 5x + 6."],
	["Algebra", "What is 2⁵?", ["10", "25", "32", "64"], 2, "2 × 2 × 2 × 2 × 2 = 32."],
	["Algebra", "√81 = ?", ["8", "9", "18", "27"], 1, "9 × 9 = 81."],
	["Geometry", "The interior angles of a triangle add up to…", ["90°", "180°", "270°", "360°"], 1, "Any triangle's interior angles sum to 180°."],
	["Geometry", "Area of a circle with radius r?", ["2πr", "πr²", "πd", "r²"], 1, "A = πr²; 2πr is the circumference."],
	["Geometry", "A right triangle has legs 3 and 4. Hypotenuse?", ["5", "6", "7", "12"], 0, "3² + 4² = 9 + 16 = 25, and √25 = 5."],
	["Statistics", "Mean of 2, 4, 6, 8?", ["4", "5", "6", "20"], 1, "(2 + 4 + 6 + 8) ÷ 4 = 20 ÷ 4 = 5."],
	["Statistics", "The median of 3, 9, 4, 7, 1 is…", ["3", "4", "7", "9"], 1, "Sorted: 1, 3, 4, 7, 9. The middle value is 4."],
	["Statistics", "A fair coin is flipped. P(heads)?", ["0", "1/4", "1/2", "1"], 2, "Two equally likely outcomes, one of them heads: 1/2."],
	["Physics", "SI unit of force?", ["Joule", "Newton", "Watt", "Pascal"], 1, "Force is measured in newtons (N = kg·m/s²)."],
	["Physics", "A 2 kg cart accelerates at 3 m/s². Net force?", ["1.5 N", "5 N", "6 N", "9 N"], 2, "F = m·a = 2 kg × 3 m/s² = 6 N."],
	["Physics", "Objects at rest stay at rest unless acted on by a net force. This is…", ["Newton's 1st law", "Newton's 2nd law", "Newton's 3rd law", "Ohm's law"], 0, "Newton's first law describes inertia."],
	["Physics", "Speed = distance ÷ …", ["mass", "time", "force", "area"], 1, "Speed is distance travelled per unit time."],
	["Physics", "Ohm's law relates V, I and R as…", ["V = I/R", "V = IR", "V = I + R", "V = R/I"], 1, "Voltage equals current times resistance."],
	["Chemistry", "Chemical symbol for sodium?", ["S", "So", "Na", "N"], 2, "Na comes from the Latin natrium."],
	["Chemistry", "pH 7 at 25 °C is…", ["Acidic", "Neutral", "Basic", "Salty"], 1, "Pure water at 25 °C is neutral, pH 7."],
	["Chemistry", "Water's chemical formula?", ["H₂O", "HO₂", "H₂O₂", "OH"], 0, "Two hydrogen atoms bonded to one oxygen atom."],
	["Biology", "The powerhouse of the cell is the…", ["Nucleus", "Ribosome", "Mitochondrion", "Membrane"], 2, "Mitochondria produce most of the cell's ATP."],
	["Biology", "Plants make food through…", ["Respiration", "Photosynthesis", "Digestion", "Fermentation"], 1, "Photosynthesis turns light, water and CO₂ into glucose."],
	["Biology", "DNA is found mainly in the cell's…", ["Nucleus", "Cell wall", "Vacuole", "Cytoplasm"], 0, "In eukaryotic cells, most DNA is in the nucleus."],
	["Computing", "Which data structure is First-In, First-Out?", ["Stack", "Queue", "Tree", "Set"], 1, "A queue removes items in the order they arrived."],
	["Computing", "Which data structure is Last-In, First-Out?", ["Queue", "Stack", "Array", "Graph"], 1, "A stack removes the most recently added item first."],
	["Computing", "Binary search on a sorted list runs in…", ["O(1)", "O(log n)", "O(n)", "O(n²)"], 1, "Each step halves the remaining range."],
	["Computing", "How many bits are in a byte?", ["4", "8", "16", "32"], 1, "A byte is 8 bits."],
	["Computing", "Binary 1111 in decimal?", ["7", "8", "15", "16"], 2, "8 + 4 + 2 + 1 = 15."],
	["Computing", "HTML is mainly used to…", ["Style pages", "Structure web content", "Run databases", "Compile code"], 1, "HTML describes the structure of web content; CSS styles it."],
	["Computing", "A variable that never changes is called a…", ["Loop", "Constant", "Function", "Pointer"], 1, "Constants keep the same value throughout a program."],
	["Computing", "`if` statements are used for…", ["Repetition", "Decisions", "Storage", "Networking"], 1, "Conditionals choose which code runs."],
	["English", "Choose the correct sentence.", ["Their going home.", "They're going home.", "There going home.", "Theyre going home."], 1, "They're = they are."],
	["English", "A word that describes a noun is an…", ["Adverb", "Adjective", "Verb", "Preposition"], 1, "Adjectives describe or modify nouns."],
	["English", "Synonym of 'rapid'?", ["Slow", "Quick", "Quiet", "Heavy"], 1, "Rapid and quick both mean fast."],
	["English", "Plural of 'analysis'?", ["Analysises", "Analyses", "Analysis", "Analysi"], 1, "Words ending in -is often change to -es: analyses."],
	["Filipino", "Ano ang kasingkahulugan ng 'masaya'?", ["Malungkot", "Maligaya", "Galit", "Pagod"], 1, "Ang 'maligaya' ay kasingkahulugan ng 'masaya'."],
	["Filipino", "Ano ang kasalungat ng 'mataas'?", ["Mababa", "Malaki", "Mahaba", "Malapad"], 0, "Ang 'mababa' ang kasalungat ng 'mataas'."],
	["Geography", "The largest ocean on Earth is the…", ["Atlantic", "Indian", "Arctic", "Pacific"], 3, "The Pacific Ocean is the largest and deepest."],
	["Geography", "The Philippines has about how many islands?", ["700", "2,000", "7,600", "20,000"], 2, "Official counts list over 7,600 islands."],
	["Economics", "When demand rises and supply stays the same, price usually…", ["Falls", "Rises", "Stays zero", "Disappears"], 1, "Higher demand with fixed supply pushes prices up."],
	["Study skills", "Spacing reviews over several days usually…", ["Hurts memory", "Improves long-term memory", "Has no effect", "Only helps math"], 1, "Spaced practice strengthens long-term retention."],
]

static func build(seed_value: int, count := 50) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bank: Array[Dictionary] = []
	var order: Array[int] = []
	for i in ITEMS.size(): order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := order[i]; order[i] = order[j]; order[j] = t
	for idx in order:
		if bank.size() >= count:
			break
		var item: Array = ITEMS[idx]
		var options: Array[String] = []
		for o in item[2]: options.append(String(o))
		var correct := String(options[int(item[3])])
		if options.size() > 2:
			for i in range(options.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t := options[i]; options[i] = options[j]; options[j] = t
		bank.append({"prompt": item[1], "options": options, "answer_index": options.find(correct), "explanation": item[4], "subject": item[0], "source": "practice"})
	var n := 0
	while bank.size() < count:
		bank.append(_arithmetic(n, rng))
		n += 1
	return bank

static func _arithmetic(i: int, rng: RandomNumberGenerator) -> Dictionary:
	var tier := 1 + int(i / 12)
	var a := rng.randi_range(3, 9 + 6 * tier)
	var b := rng.randi_range(2, 6 + 4 * tier)
	var prompt := ""
	var answer := 0
	var why := ""
	match i % 4:
		0:
			prompt = "What is %d + %d?" % [a, b]; answer = a + b; why = "%d + %d = %d." % [a, b, answer]
		1:
			prompt = "What is %d − %d?" % [a + b, b]; answer = a; why = "%d − %d = %d." % [a + b, b, answer]
		2:
			prompt = "What is %d × %d?" % [a, b]; answer = a * b; why = "%d groups of %d make %d." % [a, b, answer]
		_:
			prompt = "What is %d ÷ %d?" % [a * b, b]; answer = a; why = "%d × %d = %d, so %d ÷ %d = %d." % [a, b, a * b, a * b, b, a]
	var set := {answer: true}
	var options: Array[String] = [str(answer)]
	for delta in [tier, -tier, b, 1, -1, 2]:
		var v: int = answer + delta
		if v >= 0 and not set.has(v) and options.size() < 4:
			set[v] = true
			options.append(str(v))
	for k in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t := options[k]; options[k] = options[j]; options[j] = t
	return {"prompt": prompt, "options": options, "answer_index": options.find(str(answer)), "explanation": why, "subject": "Arithmetic", "source": "practice"}
