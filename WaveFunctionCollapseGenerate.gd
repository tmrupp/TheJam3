extends TileMap

@export var width:int
@export var height:int

var patterns # list of patterns
var patternWeights # elements are pairwise with 'patterns'; represents weight of a given pattern in a sample (i.e. number of occurances)

var possibleOptions # Options for each cell as the algorithm works out

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

# modifies 'patterns', 'patternWeights'
func parseSampleForPatterns(sampleArray, patternSize:int):
	patterns = []
	patternWeights = []
	# for each row
	for x in range(sampleArray.size - patternSize + 1):
		# for each column
		for y in range(sampleArray[0].size - patternSize + 1):
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

func generateTerrainGrid(width:int, height:int):
	pass

# Called when the node enters the scene tree for the first time.
func _ready():
	generateTerrainGrid(width, height)
	pass # Replace with function body.
