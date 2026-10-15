// Ayuda del formulario de venta: muestra la existencia del lote elegido y
// preselecciona la bodega donde esta almacenado. La validacion real la hace
// sp_registrar_venta en la base.
(function () {
    'use strict';

    var lote = document.getElementById('lote');
    var peso = document.getElementById('peso');
    var bodega = document.getElementById('bodega');
    var ayuda = document.getElementById('ayuda-peso');
    if (!lote || !peso || !ayuda) { return; }

    var basico = ayuda.textContent;

    function seleccionado() {
        return lote.options[lote.selectedIndex] || null;
    }

    function disponible() {
        var op = seleccionado();
        var v = op ? parseFloat(op.getAttribute('data-peso')) : NaN;
        return isNaN(v) ? null : v;
    }

    function actualizar() {
        var total = disponible();
        var pedido = parseFloat(peso.value);

        if (total === null) {
            ayuda.textContent = basico;
            ayuda.classList.remove('ayuda-alerta');
            return;
        }

        peso.max = total;

        if (isNaN(pedido) || pedido <= 0) {
            ayuda.textContent = 'Existencia en bodega: ' + total.toFixed(2) + ' qq.';
            ayuda.classList.remove('ayuda-alerta');
            return;
        }

        if (pedido > total) {
            ayuda.textContent = 'Solo hay ' + total.toFixed(2) +
                ' qq en bodega: la base va a rechazar la venta.';
            ayuda.classList.add('ayuda-alerta');
            return;
        }

        var resto = total - pedido;
        ayuda.textContent = resto === 0
            ? 'Se vende todo el lote: quedará en estado Vendido.'
            : 'Quedarán ' + resto.toFixed(2) + ' qq en bodega.';
        ayuda.classList.remove('ayuda-alerta');
    }

    function preseleccionarBodega() {
        var op = seleccionado();
        if (!bodega || !op) { return; }
        var id = op.getAttribute('data-bodega');
        if (id) { bodega.value = id; }
    }

    lote.addEventListener('change', function () {
        preseleccionarBodega();
        actualizar();
    });
    peso.addEventListener('input', actualizar);
    actualizar();
})();
