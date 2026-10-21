// Ayuda del ingreso a bodega: limita la cantidad a lo que falta del lote.
// La validacion real la hacen sp_registrar_ingreso_bodega y el trigger.
(function () {
    'use strict';

    var lote = document.getElementById('lote');
    var cantidad = document.getElementById('cantidad');
    var ayuda = document.getElementById('ayuda-cantidad');
    if (!lote || !cantidad) { return; }

    var base = ayuda ? ayuda.textContent : '';

    function actualizar() {
        var op = lote.options[lote.selectedIndex];

        // Sin lote elegido el formulario queda en blanco.
        if (!op || !op.value) {
            cantidad.value = '';
            cantidad.removeAttribute('max');
            if (ayuda) { ayuda.textContent = base; }
            return;
        }

        var disponible = parseFloat(op.getAttribute('data-disponible'));
        if (isNaN(disponible)) { return; }

        cantidad.max = disponible;

        if (!cantidad.value || parseFloat(cantidad.value) > disponible) {
            cantidad.value = disponible.toFixed(2);
        }

        if (ayuda) {
            ayuda.textContent = 'Pendiente de ingresar: ' + disponible.toFixed(2) + ' qq.';
        }
    }

    lote.addEventListener('change', actualizar);
    actualizar();
})();
