// Filtro en vivo de las tablas de reporte. Oculta las filas que no
// contienen el texto buscado y actualiza el contador. Sin librerias.
(function () {
    'use strict';

    var campo = document.getElementById('filtro-tabla');
    var contador = document.getElementById('contador-filas');
    if (!campo) { return; }

    var tabla = document.getElementById(campo.dataset.tabla);
    if (!tabla) { return; }

    var filas = Array.prototype.slice.call(tabla.tBodies[0].rows);

    // Se guarda el texto de cada fila una sola vez.
    var textos = filas.map(function (fila) {
        return fila.textContent.toLowerCase();
    });

    function filtrar() {
        var buscado = campo.value.trim().toLowerCase();
        var visibles = 0;

        filas.forEach(function (fila, i) {
            var coincide = buscado === '' || textos[i].indexOf(buscado) !== -1;
            fila.hidden = !coincide;
            if (coincide) { visibles++; }
        });

        if (contador) { contador.textContent = visibles; }
        tabla.classList.toggle('sin-coincidencias', visibles === 0);
    }

    campo.addEventListener('input', filtrar);
})();
