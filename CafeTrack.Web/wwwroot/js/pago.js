// Formulario de pago al productor. Arranca en blanco; al elegir la venta
// arma su ficha, propone el precio de venta y lleva la liquidacion en vivo.
// El calculo que vale es el de sp_registrar_pago y la columna generada
// monto_neto; esto solo lo muestra antes de guardar.
(function () {
    'use strict';

    var venta = document.getElementById('venta');
    var precio = document.getElementById('precio');
    var deducciones = document.getElementById('deducciones');
    if (!venta || !precio) { return; }

    var ficha = document.getElementById('ficha');
    var ayudaPrecio = document.getElementById('ayuda-precio');
    var ayudaDeducciones = document.getElementById('ayuda-deducciones');
    var lineaMonto = document.getElementById('cuenta-monto');
    var lineaDeducciones = document.getElementById('cuenta-deducciones');
    var lineaNeto = document.getElementById('cuenta-neto');
    var detalle = document.getElementById('cuenta-detalle');

    function quetzales(n) {
        return 'Q ' + n.toLocaleString('es-GT', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    function opcion() {
        return venta.options[venta.selectedIndex] || null;
    }

    function numero(atributo) {
        var op = opcion();
        var v = op ? parseFloat(op.getAttribute(atributo)) : NaN;
        return isNaN(v) ? null : v;
    }

    function texto(id, valor) {
        var campo = document.getElementById(id);
        if (campo) { campo.textContent = valor; }
    }

    function llenarFicha() {
        var op = opcion();
        if (!ficha) { return; }

        if (!op || !op.value) {
            ficha.hidden = true;
            return;
        }

        var qq = numero('data-peso');
        var total = numero('data-total');
        var bodega = op.getAttribute('data-bodega') || '';

        texto('ficha-lote', op.getAttribute('data-lote') || '—');
        texto('ficha-productor', op.getAttribute('data-productor') || '—');
        texto('ficha-comprador', op.getAttribute('data-comprador') || '—');
        texto('ficha-venta', (qq === null ? '—' : qq.toFixed(2) + ' qq') +
            (total === null ? '' : ' · ' + quetzales(total)) +
            (bodega ? ' · ' + bodega : ''));
        texto('ficha-forma', (op.getAttribute('data-forma') || '—') +
            ' · ' + (op.getAttribute('data-fecha') || ''));

        ficha.hidden = false;
    }

    /// Compara lo que se le paga al productor con lo que pagó el comprador:
    /// ahí se ve de un vistazo el margen que queda la cooperativa.
    function revisarPrecio() {
        if (!ayudaPrecio) { return; }

        var venta_ = numero('data-precio');
        var p = parseFloat(precio.value);

        if (venta_ === null || isNaN(p) || p <= 0) {
            ayudaPrecio.textContent = 'Lo acordado con el productor.';
            ayudaPrecio.classList.remove('ayuda-alerta');
            return;
        }

        if (p > venta_) {
            ayudaPrecio.textContent = 'Es ' + quetzales(p - venta_) +
                ' más de lo que pagó el comprador: la cooperativa pierde.';
            ayudaPrecio.classList.add('ayuda-alerta');
            return;
        }

        ayudaPrecio.textContent = 'El comprador pagó ' + quetzales(venta_) +
            ' por quintal; quedan ' + quetzales(venta_ - p) + ' para la cooperativa.';
        ayudaPrecio.classList.remove('ayuda-alerta');
    }

    function calcular() {
        var qq = numero('data-peso');
        var p = parseFloat(precio.value);
        var d = parseFloat(deducciones ? deducciones.value : '0');
        if (isNaN(d) || d < 0) { d = 0; }

        if (qq === null || isNaN(p) || p <= 0) {
            if (lineaMonto) { lineaMonto.textContent = quetzales(0); }
            if (lineaDeducciones) { lineaDeducciones.textContent = '− ' + quetzales(0); }
            if (lineaNeto) { lineaNeto.textContent = quetzales(0); }
            if (detalle) { detalle.textContent = 'Elija la venta y escriba el precio acordado.'; }
            if (ayudaDeducciones) { ayudaDeducciones.classList.remove('ayuda-alerta'); }
            return;
        }

        var monto = qq * p;

        if (lineaMonto) { lineaMonto.textContent = quetzales(monto); }
        if (lineaDeducciones) { lineaDeducciones.textContent = '− ' + quetzales(d); }

        if (d > monto) {
            if (lineaNeto) { lineaNeto.textContent = quetzales(0); }
            if (detalle) {
                detalle.textContent = 'Las deducciones superan el monto: la base lo rechaza.';
            }
            if (ayudaDeducciones) {
                ayudaDeducciones.textContent = 'No pueden pasar de ' + quetzales(monto) + '.';
                ayudaDeducciones.classList.add('ayuda-alerta');
            }
            return;
        }

        if (lineaNeto) { lineaNeto.textContent = quetzales(monto - d); }

        if (ayudaDeducciones) {
            ayudaDeducciones.textContent =
                'Insumos, anticipos, transporte. No pueden superar el monto.';
            ayudaDeducciones.classList.remove('ayuda-alerta');
        }

        if (detalle) {
            detalle.textContent = qq.toFixed(2) + ' qq × ' + quetzales(p) +
                ' por quintal' + (d > 0 ? ', menos ' + quetzales(d) + ' de deducciones' : '') + '.';
        }
    }

    function actualizar() {
        revisarPrecio();
        calcular();
    }

    venta.addEventListener('change', function () {
        var op = opcion();

        // Sin venta elegida el formulario queda en blanco.
        if (!op || !op.value) {
            precio.value = '';
            if (deducciones) { deducciones.value = ''; }
            llenarFicha();
            actualizar();
            return;
        }

        // Se propone el precio de la venta como punto de partida.
        var sugerido = numero('data-precio');
        if (!precio.value && sugerido !== null) {
            precio.value = sugerido.toFixed(2);
        }

        llenarFicha();
        actualizar();
    });

    precio.addEventListener('input', actualizar);
    if (deducciones) { deducciones.addEventListener('input', actualizar); }

    // Al recargar, el navegador reescribe los campos: se vuelve a lo que
    // mando el servidor (en blanco al entrar, con los datos si hubo error).
    (function arrancarLimpio() {
        var form = venta.closest('form');
        if (!form) { return; }

        form.querySelectorAll('input').forEach(function (campo) {
            if (campo.type === 'hidden' || campo.readOnly) { return; }
            campo.value = campo.defaultValue;
        });

        form.querySelectorAll('select').forEach(function (lista) {
            for (var i = 0; i < lista.options.length; i++) {
                if (lista.options[i].defaultSelected) { lista.selectedIndex = i; return; }
            }
            lista.selectedIndex = 0;
        });
    })();

    llenarFicha();
    actualizar();
})();
