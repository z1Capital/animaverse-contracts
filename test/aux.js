const web3Utils = require('web3-utils')

function generateGame() {
  return { score: 100, gameData: Math.random().toString(), sr: parseInt((Math.random() * 10 ** 8).toFixed()) }
}

async function validateGame(validateData, gameData) {
  if (gameData === 'xxx' && validateData === 'yyy') {
    return { valid: false, message: 'gameData is not valid' }
  } else {
    return { valid: true, message: 'gameData is valid' }
  }
}

function getLeaf(game) {
  return web3Utils.soliditySha3(
    { value: game.index, type: 'uint256' },
    { value: game.score, type: 'uint256' },
    { value: game.sr, type: 'uint256' }
  )
}

module.exports = {
  generateGame,
  validateGame,
  getLeaf,
}
