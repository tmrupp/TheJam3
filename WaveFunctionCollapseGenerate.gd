extends TileMap

@export var width:int
@export var height:int
@export var patternSize:int

var patterns:Array[Pattern] # list of patterns
var patternWeights:Array[int] # elements are pairwise with 'patterns'; represents weight of a given pattern in a sample (i.e. number of occurances)
var totalWeight:int # the sum of the elements of 'patternWeights'; calculated once when sample array is read then never changed

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
			endCoord.x = size - direction.x
		
		if direction.y > 0:
			startCoord.y = direction.y
			endCoord.y = size
		else:
			startCoord.y = 0;
			endCoord.y = size - direction.y
			
		for x in range(startCoord.x, endCoord.x):
			for y in range(startCoord.y, endCoord.y):
				if data[x][y] != other.data[x-direction.x][y-direction.y]:
					return false
		return true
			
	func matchesExactly(other:Pattern):
		return matchesExactly_rawData(other.data)
	
	func matchesExactly_rawData(other):
		for x in range(data.size):
			for y in range(data[x].size):
				if data[x][y] != other[x][y]:
					return false
		return true
		
	# returns Array[Vector2i]
	static func generateDirectionListFromSize(size:int):
		var directions = []
		for x in range(-(size-1), size):
			for y in range(-(size-1), size):
				directions.append(Vector2i(x, y))

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
				pattern.append(sampleArray[x+s].slice(y, patternSize))
			
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

# returns float
func getEntropy(x:int, y:int):
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
func getLeastNonzeroEntropy():
	var least:float = INF
	for x in range(width):
		for y in range(height):
			if currentEntropy[x][y] < least && currentEntropy[x][y] > 0:
				least = currentEntropy[x][y]
	return least

# returns int
func getWeightedRandomCellOption(pos:Vector2i):
	var totalCurrentWeight:int = 0
	for pattern in currentOptions[pos.x][pos.y]:
		totalCurrentWeight += patternWeights[pattern]
		
	var rand:int = randi_range(0, totalCurrentWeight)
	
	var current:int = 0
	var currentWeight:int = 0
	while current < currentOptions.size():
		if rand <= currentWeight:
			return currentOptions[pos.x][pos.y][current]
		currentWeight += patternWeights[currentOptions[pos.x][pos.y][current]]
		current += 1
	
	return currentOptions[pos.x][pos.y][-1]

func collapse(pos:Vector2i):
	while currentOptions[pos.x][pos.y].size() > 0:
		var collapsedValue:int = getWeightedRandomCellOption(pos)
		currentOptions[pos.x][pos.y] = [collapsedValue]
		currentEntropy[pos.x][pos.y] = 0
		
		# propagate to neighbors

# modifies 'currentOptions'
# modifies 'currentEntropy'
func generateTerrainGrid(width:int, height:int):
	# fill 'possibleOptions' grid with all possible options, i.e. [0, 1, 2, ..., patterns.size()] for each cell
	currentOptions = []
	for x in range(width):
		currentOptions.append([])
		for y in range(height):
			currentOptions[-1].append([])
			for i in range(patterns.size()):
				currentOptions[-1][-1].append(i)
				
	# fill 'currentEntropy' array
	for x in range(width):
		for y in range(height):
			currentEntropy[x][y] = getEntropy(x, y)
	
	while not isEveryCellDecided():
		var pos:Vector2i = getLeastNonzeroEntropy()
		collapse(pos)

# Called when the node enters the scene tree for the first time.
func _ready():
	var sampleImage # TODO: read image information sample
	parseSampleForPatterns(sampleImage, patternSize)
	generateTerrainGrid(width, height)
	# TODO: set MapInfo values based on finished map
