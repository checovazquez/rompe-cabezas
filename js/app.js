const screens = {
    register: document.getElementById("screen-register"),
    preview: document.getElementById("screen-preview"),
    game: document.getElementById("screen-game"),
    result: document.getElementById("screen-result")
};

const phoneInput = document.getElementById("phone-input");
const startBtn = document.getElementById("start-btn");
const restartBtn = document.getElementById("restart-btn");

const previewImage = document.getElementById("preview-image");
const previewTimer = document.getElementById("preview-timer");

const gameTimer = document.getElementById("game-timer");
const board = document.getElementById("board");
const piecesArea = document.getElementById("pieces-area");

const resultTitle = document.getElementById("result-title");
const resultTime = document.getElementById("result-time");
const rankingList = document.getElementById("ranking-list");

const gameState = {
    phone: "",
    selectedProduct: null,
    previewSeconds: 10,
    maxGameSeconds: 60,
    previewInterval: null,
    gameInterval: null,
    allPieces: [],
    correctPieces: [],
    distractorPieces: [],
    gamePieces: [],
    draggedPieceId: null,
    lockedPositions: [],
    placedCorrectCount: 0,
    gameStartTime: null,
    elapsedMs: 0,
    gameFinished: false
};

const products = [
    { id: 1, image: "assets/products/producto1.jpg" },
    { id: 2, image: "assets/products/producto2.jpg" },
    { id: 3, image: "assets/products/producto3.jpg" },
    { id: 4, image: "assets/products/producto4.jpg" },
    { id: 5, image: "assets/products/producto5.jpg" }
];

function buildAllPieces() {
    const allPieces = [];

    for (let productId = 1; productId <= 5; productId++) {
        for (let position = 1; position <= 9; position++) {
            allPieces.push({
                id: `p${productId}_${position}`,
                productId: productId,
                position: position,
                image: `assets/pieces/p${productId}_${position}.png`
            });
        }
    }

    return allPieces;
}

function shuffleArray(array) {
    const copy = [...array];

    for (let i = copy.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [copy[i], copy[j]] = [copy[j], copy[i]];
    }

    return copy;
}

function showScreen(screenName) {
    Object.values(screens).forEach((screen) => {
        screen.classList.remove("active");
    });

    screens[screenName].classList.add("active");
}

function formatTime(milliseconds) {
    const totalCentiseconds = Math.floor(milliseconds / 10);
    const minutes = String(Math.floor(totalCentiseconds / 6000)).padStart(2, "0");
    const seconds = String(Math.floor((totalCentiseconds % 6000) / 100)).padStart(2, "0");
    const centiseconds = String(totalCentiseconds % 100).padStart(2, "0");

    return `${minutes}:${seconds}.${centiseconds}`;
}

function getMaxTimeMs() {
    return gameState.maxGameSeconds * 1000;
}

function getStoredRanking() {
    const saved = localStorage.getItem("rompeMasecasRanking");
    return saved ? JSON.parse(saved) : [];
}

function saveStoredRanking(ranking) {
    localStorage.setItem("rompeMasecasRanking", JSON.stringify(ranking));
}

function maskPhone(phone) {
    if (!phone || phone.length < 4) return phone;
    return `******${phone.slice(-4)}`;
}

function renderRanking() {
    if (!rankingList) return;

    const ranking = getStoredRanking();
    rankingList.innerHTML = "";

    if (ranking.length === 0) {
        rankingList.innerHTML = '<div class="empty-ranking">Todavia no hay tiempos registrados.</div>';
        return;
    }

    ranking.slice(0, 20).forEach((item, index) => {
        const row = document.createElement("div");
        row.className = "ranking-item";

        row.innerHTML = `
      <div class="ranking-position">${index + 1}.</div>
      <div class="ranking-phone">${maskPhone(item.phone)}</div>
      <div class="ranking-time">${item.timeText}</div>
    `;

        rankingList.appendChild(row);
    });
}

function saveResult(completed) {
    const finalTimeMs = completed ? gameState.elapsedMs : getMaxTimeMs();

    const result = {
        phone: gameState.phone,
        timeMs: finalTimeMs,
        timeText: formatTime(finalTimeMs),
        productId: gameState.selectedProduct.id,
        completed: completed,
        playedAt: new Date().toISOString()
    };

    const ranking = getStoredRanking();
    ranking.push(result);

    ranking.sort((a, b) => {
        if (a.timeMs !== b.timeMs) {
            return a.timeMs - b.timeMs;
        }

        return new Date(a.playedAt) - new Date(b.playedAt);
    });

    saveStoredRanking(ranking);
}

function getRandomProduct() {
    const randomIndex = Math.floor(Math.random() * products.length);
    return products[randomIndex];
}

function validatePhone(phone) {
    return /^[0-9]{10}$/.test(phone);
}

function getCorrectPieces(productId) {
    return gameState.allPieces.filter((piece) => piece.productId === productId);
}

function getDistractorPieces(productId) {
    const otherPieces = gameState.allPieces.filter((piece) => piece.productId !== productId);
    const shuffled = shuffleArray(otherPieces);
    return shuffled.slice(0, 11);
}

function prepareGamePieces() {
    const productId = gameState.selectedProduct.id;

    gameState.correctPieces = getCorrectPieces(productId);
    gameState.distractorPieces = getDistractorPieces(productId);
    gameState.gamePieces = shuffleArray([
        ...gameState.correctPieces,
        ...gameState.distractorPieces
    ]);
}

function getPieceById(pieceId) {
    return gameState.gamePieces.find((piece) => piece.id === pieceId);
}

function isCorrectPiece(piece, slotPosition) {
    const isFromSelectedProduct = piece.productId === gameState.selectedProduct.id;
    const isCorrectPosition = piece.position === slotPosition;

    return isFromSelectedProduct && isCorrectPosition;
}

function startPreview() {
    clearInterval(gameState.previewInterval);

    gameState.previewSeconds = 10;
    previewTimer.textContent = gameState.previewSeconds;

    gameState.previewInterval = setInterval(() => {
        gameState.previewSeconds -= 1;
        previewTimer.textContent = gameState.previewSeconds;

        if (gameState.previewSeconds <= 0) {
            clearInterval(gameState.previewInterval);
            startGame();
        }
    }, 1000);
}

function createBoard() {
    board.innerHTML = "";

    for (let i = 1; i <= 9; i++) {
        const slot = document.createElement("div");
        slot.className = "drop-slot";
        slot.dataset.position = i;

        const slotLabel = document.createElement("span");
        slotLabel.className = "slot-label";
        slotLabel.textContent = i;

        slot.appendChild(slotLabel);
        board.appendChild(slot);
    }
}

function renderPieces() {
    piecesArea.innerHTML = "";

    gameState.gamePieces.forEach((piece) => {
        const pieceElement = document.createElement("img");
        pieceElement.className = "piece";
        pieceElement.src = piece.image;
        pieceElement.alt = piece.id;

        pieceElement.dataset.id = piece.id;
        pieceElement.dataset.productId = piece.productId;
        pieceElement.dataset.position = piece.position;

        pieceElement.draggable = true;

        pieceElement.addEventListener("dragstart", (event) => {
    if (pieceElement.classList.contains("locked")) {
        event.preventDefault();
        return;
    }

    gameState.draggedPieceId = piece.id;
    pieceElement.classList.add("dragging");

    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", piece.id);
});

        pieceElement.addEventListener("dragend", () => {
            pieceElement.classList.remove("dragging");
            gameState.draggedPieceId = null;
        });

        piecesArea.appendChild(pieceElement);
    });
}

function setupBoardDropEvents() {
    const slots = board.querySelectorAll(".drop-slot");

    slots.forEach((slot) => {
        slot.addEventListener("dragover", (event) => {
            event.preventDefault();
            slot.classList.add("hovered");
        });

        slot.addEventListener("dragleave", () => {
            slot.classList.remove("hovered");
        });

        slot.addEventListener("drop", (event) => {
            event.preventDefault();
            slot.classList.remove("hovered");

            if (!gameState.draggedPieceId) return;

            const piece = getPieceById(gameState.draggedPieceId);
            if (!piece) return;

            const slotPosition = Number(slot.dataset.position);

            if (gameState.lockedPositions.includes(slotPosition)) {
                return;
            }

            if (isCorrectPiece(piece, slotPosition)) {
                placePieceInSlot(piece, slot);
            } else {
                resetPiecePosition(piece.id);
            }
        });
    });
}

function placePieceInSlot(piece, slot) {
    const pieceElement = document.querySelector(`.piece[data-id="${piece.id}"]`);
    if (!pieceElement) return;

    pieceElement.classList.add("locked");
    pieceElement.draggable = false;

    const label = slot.querySelector(".slot-label");
    if (label) {
        label.remove();
    }

    slot.appendChild(pieceElement);
    slot.classList.add("correct");
    slot.classList.add("correct-flash");

    setTimeout(() => {
        slot.classList.remove("correct-flash");
    }, 280);

    gameState.lockedPositions.push(piece.position);
    gameState.placedCorrectCount += 1;

    if (gameState.placedCorrectCount === 9) {
        clearInterval(gameState.gameInterval);
        endGame(true);
    }
}

function resetPiecePosition(pieceId) {
    const pieceElement = document.querySelector(`.piece[data-id="${pieceId}"]`);
    if (!pieceElement) return;

    pieceElement.classList.add("wrong");

    setTimeout(() => {
        pieceElement.classList.remove("wrong");
        piecesArea.appendChild(pieceElement);
    }, 280);
}

function startGame() {
    clearInterval(gameState.gameInterval);

    showScreen("game");
    createBoard();
    prepareGamePieces();
    renderPieces();
    setupBoardDropEvents();

    gameState.lockedPositions = [];
    gameState.placedCorrectCount = 0;
    gameState.gameFinished = false;
    gameState.elapsedMs = 0;
    gameState.gameStartTime = Date.now();

    gameTimer.textContent = formatTime(0);

    gameState.gameInterval = setInterval(() => {
        const now = Date.now();
        gameState.elapsedMs = now - gameState.gameStartTime;

        if (gameState.elapsedMs >= getMaxTimeMs()) {
            gameState.elapsedMs = getMaxTimeMs();
            gameTimer.textContent = formatTime(gameState.elapsedMs);
            clearInterval(gameState.gameInterval);
            endGame(false);
            return;
        }

        gameTimer.textContent = formatTime(gameState.elapsedMs);
    }, 10);
}

function endGame(completed) {
    if (gameState.gameFinished) return;
    gameState.gameFinished = true;

    clearInterval(gameState.gameInterval);

    if (completed) {
        gameState.elapsedMs = Date.now() - gameState.gameStartTime;

        if (gameState.elapsedMs > getMaxTimeMs()) {
            gameState.elapsedMs = getMaxTimeMs();
        }
    } else {
        gameState.elapsedMs = getMaxTimeMs();
    }

    saveResult(completed);

    resultTitle.textContent = completed ? "¡Lo lograste!" : "Tiempo agotado";
    resultTime.textContent = `Tu tiempo: ${formatTime(gameState.elapsedMs)}`;

    renderRanking();
    showScreen("result");
}

gameState.allPieces = buildAllPieces();
renderRanking();

startBtn.addEventListener("click", () => {
    clearInterval(gameState.previewInterval);
    clearInterval(gameState.gameInterval);

    const phone = phoneInput.value.trim();

    if (!validatePhone(phone)) {
        alert("Captura un numero celular valido de 10 digitos.");
        return;
    }

    gameState.phone = phone;
    gameState.selectedProduct = getRandomProduct();

    previewImage.src = gameState.selectedProduct.image;
    showScreen("preview");
    startPreview();
});

restartBtn.addEventListener("click", () => {
    clearInterval(gameState.previewInterval);
    clearInterval(gameState.gameInterval);

    phoneInput.value = "";
    previewImage.src = "";

    gameState.phone = "";
    gameState.selectedProduct = null;
    gameState.previewSeconds = 10;
    gameState.correctPieces = [];
    gameState.distractorPieces = [];
    gameState.gamePieces = [];
    gameState.draggedPieceId = null;
    gameState.lockedPositions = [];
    gameState.placedCorrectCount = 0;
    gameState.gameStartTime = null;
    gameState.elapsedMs = 0;
    gameState.gameFinished = false;

    piecesArea.innerHTML = "";
    board.innerHTML = "";

    showScreen("register");
});

document.addEventListener("selectstart", (event) => {
    if (!event.target.closest("#phone-input")) {
        event.preventDefault();
    }
});
