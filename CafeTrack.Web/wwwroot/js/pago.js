// Ayuda del formulario de pago: muestra el monto y el neto mientras se
// escribe. El calculo que vale es el de sp_registrar_pago.
(function () {
    'use strict';

    var venta = document.getElementById('venta');
    var precio = document.getElementById('precio');
    var deducciones = document.getElementById('deducciones');
    var ayuda = document.getElementById('ayuda-monto');
    if (!venta || !precio || !ayuda) { return; }

    function peso() {
        var op = venta.options[venta.selectedIndex];
        var v = op ? parseFloat(op.getAttribute('data-peso')) : NaN;
        return isNaN(v) ? null : v;
    }

    function quetzales(n) {
        return 'Q ' + n.toLocaleString('es-GT', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    function calcular() {
        var qq = peso();
        var p = parseFloat(precio.value);
        var d = parseFloat(deducciones ? deducciones.value : '0');
        if (isNaN(d)) { d = 0; }

        if (qq === null || isNaN(p) || p <= 0) {
            ayuda.textContent = 'El monto se calcula solo.';
            ayuda.classList.remove('ayuda-alerta');
            return;
        }

        var monto = qq * p;

        if (d > monto) {
            ayuda.textContent = 'Las deducciones (' + quetzales(d) +
                ') superan el monto de ' + quetzales(monto) + '.';
            ayuda.classList.add('ayuda-alerta');
            return;
        }

        ayuda.textContent = qq.toFixed(2) + ' qq × ' + quetzales(p) + ' = ' +
            quetzales(monto) + ' · neto ' + quetzales(monto - d);
        ayuda.classList.remove('ayuda-alerta');
    }

    // Al elegir la venta se propone el precio de venta como punto de partida.
    venta.addEventListener('change', function () {
        var op = venta.options[venta.selectedIndex];

        // Sin venta elegida el formulario queda en blanco.
        if (!op || !op.value) {
            precio.value = '';
            if (deducciones) { deducciones.value = ''; }
            calcular();
            return;
        }

        var sugerido = parseFloat(op.getAttribute('data-precio'));
        if (!precio.value && !isNaN(sugerido)) {
            precio.value = sugerido.toFixed(2);
        }

        calcular();
    });

    precio.addEventListener('input', calcular);
    if (deducciones) { deducciones.addEventListener('input', calcular); }
    calcular();
})();
