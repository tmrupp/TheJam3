extends Node

@export var width:int
@export var height:int
@export var patternSize:int
@export var maximumRecursionDepth:int

var patterns:Array[Pattern] # list of patterns
var patternWeights:Array[int] # elements are pairwise with 'patterns'; represents weight of a given pattern in a sample (i.e. number of occurances)
var totalWeight:int # the sum of the elements of 'patternWeights'; calculated once when sample array is read then never changed

var directionList:Array[Vector2i] # a list of all the valid direction offsets to compare one pattern to another; filled initially and never changed

# Array[Array[Array[int]]] x/y grid and for each cell a list that is a set of indicies
var currentOptions:Array # The current options possible for every grid square, actively changing while the algorithm runs, holds indicies into 'patterns'

# Array[Array[int]] x/y grid and for each cell its entropy
var currentEntropy:Array

class Pattern:
	# all patterns are square, this is the side length of the square
	var size:int
	# double subscripted array of length size x size
	var data
	
	func _init(_size:int, _data):
		size = _size
		data = _data
	
	# returns true when this pattern and 'other' can be laid on top of each other when offseting 'other' by 'direction'
	func cleanlyMeshesWith(other:Pattern, direction:Vector2i):
		# early exit for non-overlapping patterns
		if \
		# if the other pattern is further in the +x than ours is long in the +x
		direction.x > 0 && direction.x > size || \
		# if the other pattern is further in the +y than ours is long in the +y
		direction.y > 0 && direction.y > size || \
		# if the other pattern is further in the -x than it is long
		direction.x < 0 && abs(direction.x) > other.size || \
		# if the other pattern is further in the -y than it is long
		direction.y < 0 && abs(direction.y) > other.size:
			return true
		
		# only loop over tiles that overlap
		# set start and end coords in the source pattern
		var startCoord:Vector2i;
		var endCoord:Vector2i;
		
		if direction.x > 0:
			startCoord.x = direction.x
			endCoord.x = size
		else:
			startCoord.x = 0
			endCoord.x = size - abs(direction.x)
		
		if direction.y > 0:
			startCoord.y = direction.y
			endCoord.y = size
		else:
			startCoord.y = 0;
			endCoord.y = size - abs(direction.y)
			
		for x in range(startCoord.x, endCoord.x):
			for y in range(startCoord.y, endCoord.y):
				if data[x][y] != other.data[x-direction.x][y-direction.y]:
					return false
		return true
			
	func matchesExactly(other:Pattern):
		return matchesExactly_rawData(other.data)
	
	func matchesExactly_rawData(other):
		for x in range(data.size()):
			for y in range(data[x].size()):
				if data[x][y] != other[x][y]:
					return false
		return true
		
	# returns Array[Vector2i]
	static func generateDirectionListFromSize(size:int) -> Array[Vector2i]:
		var directions:Array[Vector2i] = []
		for x in range(-(size-1), size):
			for y in range(-(size-1), size):
				if not (x == 0 && y == 0):
					directions.append(Vector2i(x, y))
		return directions

# modifies 'patterns', 'patternWeights'
# sampleArray: Array[Array[int]] x/y grid and for each cell is an int identifying what type that cell is
func parseSampleForPatterns(sampleArray:Array, patternSize:int):
	patterns = []
	patternWeights = []
	# for each row
	for x in range(sampleArray.size() - patternSize + 1):
		# for each column
		for y in range(sampleArray[0].size() - patternSize + 1):
			# pull 'patternSize' number of rows starting from (x,y)
			var pattern = []
			for s in range(patternSize):
				pattern.append(sampleArray[x+s].slice(y, y + patternSize))
			
			# add to the pattern list if this is new
			# otherwise increase its weight
			var matchFound:bool = false
			for p in range(patterns.size()):
				if patterns[p].matchesExactly_rawData(pattern):
					matchFound = true
					patternWeights[p] += 1
					break
			if not matchFound:
				patterns.append(Pattern.new(patternSize, pattern))
				patternWeights.append(1)
				
	totalWeight = 0
	for i in patternWeights:
		totalWeight += i

func getEntropy(x:int, y:int) -> float:
	var entropy:float = 0
	
	for optionIndex in currentOptions[x][y]:
		var prob = float(patternWeights[optionIndex]) / totalWeight
		entropy += prob * log(prob) / log(2)
	
	return -entropy

func isEveryCellDecided():
	for x in range(width):
		for y in range(height):
			if currentOptions.size() > 1:
				return false
	return true

# returns Vector2i of coords of entry in grid with least entropy
func getLeastNonzeroEntropy() -> Vector2i:
	var least:float = INF
	var coordWithLeast:Vector2i = Vector2i(-1, -1)
	for x in range(width):
		for y in range(height):
			if currentEntropy[x][y] < least && currentEntropy[x][y] > 0:
				least = currentEntropy[x][y]
				coordWithLeast = Vector2i(x, y)
	return coordWithLeast

func getWeightedRandomCellOption(pos:Vector2i) -> int:
	var totalCurrentWeight:int = 0
	for pattern in currentOptions[pos.x][pos.y]:
		totalCurrentWeight += patternWeights[pattern]
		
	var rand:int = randi_range(0, totalCurrentWeight - 1)
	
	var current:int = 0
	var currentWeight:int = 0
	while current < currentOptions.size():
		if rand <= currentWeight:
			return currentOptions[pos.x][pos.y][current]
		currentWeight += patternWeights[currentOptions[pos.x][pos.y][current]]
		current += 1
	
	return currentOptions[pos.x][pos.y][-1]

# returns bool; true if the propagate was successful, false if we reached a contradiction (a cell is left with no options)
func propagate(pos:Vector2i, parentPos:Vector2i, direction:Vector2i, remainingRecursionDepth:int) -> bool:
	# early exit if this isn't a usable position
	if pos.x < 0 || pos.y < 0 || pos.x >= width || pos.y >= height:
		return true
	
	# early exit if this cell is already decided
	if currentOptions[pos.x][pos.y].size() == 0:
		return true
	
	var optionCountAtStart:int = currentOptions[pos.x][pos.y].size()
	
	# remove patterns from the cell at pos if they disagree with all the patterns available at the parentPos
	for option in currentOptions[pos.x][pos.y]:
		var foundWorkingOption:bool = false
		for parentOption in currentOptions[parentPos.x][parentPos.y]:
			if patterns[parentOption].cleanlyMeshesWith(patterns[option], direction):
				foundWorkingOption = true
				break;
		if not foundWorkingOption:
			currentOptions[pos.x][pos.y].erase(option)
	
	# if we're out of options, the original collapse wasn't something we could do and have a solvable output
	if currentOptions[pos.x][pos.y].is_empty():
		print("reached contradiction at: " + str(pos))
		return false
	
	# if we've altered this cell's options, we have to recurse to our neighbors
	if currentOptions[pos.x][pos.y].size() < optionCountAtStart:
		currentEntropy[pos.x][pos.y] = getEntropy(pos.x, pos.y)
		if remainingRecursionDepth > 0:
			for dir in directionList:
				if not propagate(pos + dir, pos, dir, remainingRecursionDepth - 1):
					print("could not propagate at " + str(pos))
					return false
	
	return true

# returns bool
func collapse(pos:Vector2i) -> bool:
	var collapsedValue:int = getWeightedRandomCellOption(pos)
	currentOptions[pos.x][pos.y] = [collapsedValue]
	currentEntropy[pos.x][pos.y] = 0
	
	# propagate to neighbors
	for direction in directionList:
		if not propagate(pos + direction, pos, direction, maximumRecursionDepth):
			print("could not propagate: " + str(collapsedValue) + " at " + str(pos))
			return false
	
	return true

func initializeGrid():
	# fill 'possibleOptions' grid with all possible options, i.e. [0, 1, 2, ..., patterns.size()] for each cell
	currentOptions = []
	for x in range(width):
		currentOptions.append([])
		for y in range(height):
			currentOptions[-1].append([])
			for i in range(patterns.size()):
				currentOptions[-1][-1].append(i)
				
	# fill 'currentEntropy' array
	currentEntropy = []
	for x in range(width):
		currentEntropy.append([])
		for y in range(height):
			currentEntropy[-1].append(getEntropy(x, y))

# modifies 'currentOptions'
# modifies 'currentEntropy'
func generateTerrainGrid(width:int, height:int):
	initializeGrid()
	
	while not isEveryCellDecided():
		var pos:Vector2i = getLeastNonzeroEntropy()
		if not collapse(pos):
			print("reached contradiction, trying again")
			initializeGrid()

# Called when the node enters the scene tree for the first time.
func _ready():
	var imageConverter = get_tree().get_root().get_child(0).find_child("ImageConverter")
	var sampleImage = imageConverter.to_array("res://pixil-frame-0.png")
	parseSampleForPatterns(sampleImage, patternSize)
	directionList = Pattern.generateDirectionListFromSize(patternSize)
	generateTerrainGrid(width, height)
	
	for x in range(width):
		for y in range(height):
			currentOptions[x][y] = currentOptions[x][y][0]
	
	var mapInfo = get_tree().get_root().get_child(0).find_child("CanvasLayer").find_child("MapInfo")
	mapInfo.load_all(currentOptions, currentOptions)
