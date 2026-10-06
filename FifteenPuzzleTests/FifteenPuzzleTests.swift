import Testing
@testable import FifteenPuzzle

@MainActor
struct FifteenPuzzleTests {
    @Test func rowsCelebrateOnlyWhenNewlyCompleted() {
        var board = PuzzleBoard()
        #expect(board.completedRows == Set(0..<4))
        _ = board.move(at: 11)
        let incomplete = board.completedRows
        #expect(incomplete == [0, 1])
        _ = board.move(at: 15)
        #expect(board.completedRows.subtracting(incomplete) == [2, 3])
        let complete = board.completedRows
        #expect(board.completedRows.subtracting(complete).isEmpty)
        board.tiles = [2, 3, 4, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0]
        #expect(!board.completedRows.contains(0))
    }
    @Test func shuffleProducesSolvableBoards() {
        var board = PuzzleBoard()
        for _ in 0..<1000 {
            board.shuffle()
            #expect(PuzzleBoard.isSolvable(board.tiles))
            #expect(!board.solved)
            #expect(Set(board.tiles) == Set(0...15))
        }
    }
    @Test func rejectsUnsolvableAndMalformedBoards() {
        var tiles = Array(1...15) + [0]
        tiles.swapAt(0, 1)
        #expect(!PuzzleBoard.isSolvable(tiles))
        #expect(!PuzzleBoard.isSolvable(Array(repeating: 0, count: 16)))
        #expect(!PuzzleBoard.isSolvable([]))
    }
    @Test func legalMovesAndWinDetection() {
        var board = PuzzleBoard()
        let moveResult1 = board.move(at: 0)
        #expect(!moveResult1)
        let moveResult2 = board.move(at: 16)
        #expect(!moveResult2)
        let moveResult3 = board.move(at: -1)
        #expect(!moveResult3)
        let moveResult4 = board.move(at: 15)
        #expect(!moveResult4)
        let moveResult5 = board.move(at: 14)
        #expect(moveResult5)
        #expect(!board.solved)
        let moveResult6 = board.move(at: 15)
        #expect(moveResult6)
        #expect(board.solved)
        board.tiles.swapAt(3, 15)
        let moveResult7 = board.move(at: 4)
        #expect(!moveResult7)
    }
}
