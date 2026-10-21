// Formulario de venta. Arranca en blanco y al elegir el lote arma la ficha,
// deja solo las bodegas donde ese lote tiene cafe y lleva la cuenta en Q.
// Quien decide de verdad es sp_registrar_venta: aqui solo se adelanta.
(function () {
    'use strict';

    var lote = document.getElementById('lote');
    var bodega = document.getElementById('bodega');
    var peso = document.getElementById('peso');
    var precio = document.getElementById('precio');
    var forma = document.getElementById('forma');
    if (!lote || !bodega || !peso || !precio) { return; }

    var ficha = document.getElementById('ficha');
    var ayudaBodega = document.getElementById('ayuda-bodega');
    var ayudaPeso = document.getElementById('ayuda-peso');
    var ayudaPrecio = document.getElementById('ayuda-precio');
    var ayudaForma = document.getElementById('ayuda-forma');
    var total = document.getElementById('cuenta-total');
    var detalle = document.getElementById('cuenta-detalle');

    function quetzales(n) {
        return 'Q ' + n.toLocaleString('es-GT', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    function numero(elemento, atributo) {
        var v = elemento ? parseFloat(elemento.getAttribute(atributo)) : NaN;
        return isNaN(v) ? null : v;
    }

    function opcionLote() {
        return lote.options[lote.selectedIndex] || null;
    }

    function opcionBodega() {
        return bodega.options[bodega.selectedIndex] || null;
    }

    /// Lo que hay del lote en la bodega elegida.
    function disponible() {
        return numero(opcionBodega(), 'data-cantidad');
    }

    // ------------------------------------------------- ficha del lote

    function texto(id, valor) {
        var campo = document.getElementById(id);
        if (campo) { campo.textContent = valor; }
    }

    function llenarFicha() {
        var op = opcionLote();

        if (!ficha) { return; }

        if (!op || !op.value) {
            ficha.hidden = true;
            return;
        }

        var puntaje = numero(op, 'data-puntaje');
        var base = numero(op, 'data-base');
        var altura = op.getAttribute('data-altura') || '';
        var anio = op.getAttribute('data-anio') || '';

        texto('ficha-productor', op.getAttribute('data-productor') || '—');
        texto('ficha-variedad', op.getAttribute('data-variedad') || '—');
        texto('ficha-catacion', puntaje === null
            ? '—'
            : puntaje.toFixed(2) + ' SCA' + (altura ? ' · ' + altura : ''));
        texto('ficha-base', base === null
            ? 'Sin precio base'
            : quetzales(base) + (anio ? ' · temporada ' + anio : ''));

        ficha.hidden = false;
    }

    // ------------------------------- bodegas donde esta guardado el lote

    /// Deja visibles solo las bodegas del lote elegido. Si hay una sola,
    /// la toma; asi no se puede despachar de una bodega equivocada.
    function filtrarBodegas() {
        var op = opcionLote();
        var id = op ? op.value : '';
        var quedan = [];

        for (var i = 0; i < bodega.options.length; i++) {
            var o = bodega.options[i];

            if (!o.value) { continue; }

            var suyo = o.getAttribute('data-lote') === id;
            o.hidden = !suyo;
            o.disabled = !suyo;

            if (suyo) { quedan.push(o); }
        }

        if (quedan.length === 1) {
            bodega.value = quedan[0].value;
        } else if (!quedan.some(function (o) { return o.value === bodega.value; })) {
            bodega.value = '';
        }

        if (ayudaBodega) {
            if (!id) {
                ayudaBodega.textContent = 'Solo aparecen las bodegas que tienen ese lote.';
            } else if (quedan.length === 0) {
                ayudaBodega.textContent = 'Ese lote no está en ninguna bodega.';
            } else if (quedan.length === 1) {
                ayudaBodega.textContent = 'Está en una sola bodega: ya quedó elegida.';
            } else {
                ayudaBodega.textContent = 'Está repartido en ' + quedan.length +
                    ' bodegas; elija de cuál sale.';
            }
        }

        if (ficha) { texto('ficha-bodegas', resumenBodegas(quedan)); }
    }

    function resumenBodegas(opciones) {
        if (opciones.length === 0) { return '—'; }

        return opciones.map(function (o) {
            return o.textContent.trim();
        }).join(' · ');
    }

    // ------------------------------------------------ cantidad y cuenta

    function revisarPeso() {
        var hay = disponible();
        var pedido = parseFloat(peso.value);

        if (!ayudaPeso) { return; }

        if (hay === null) {
            peso.removeAttribute('max');
            ayudaPeso.textContent = 'No puede superar lo que hay en esa bodega.';
            ayudaPeso.classList.remove('ayuda-alerta');
            return;
        }

        peso.max = hay;

        if (isNaN(pedido) || pedido <= 0) {
            ayudaPeso.textContent = 'En esa bodega hay ' + hay.toFixed(2) + ' qq.';
            ayudaPeso.classList.remove('ayuda-alerta');
            return;
        }

        if (pedido > hay) {
            ayudaPeso.textContent = 'Esa bodega solo tiene ' + hay.toFixed(2) +
                ' qq: la base va a rechazar la venta.';
            ayudaPeso.classList.add('ayuda-alerta');
            return;
        }

        var resto = hay - pedido;
        ayudaPeso.textContent = resto === 0
            ? 'Se despacha todo lo que había en esa bodega.'
            : 'Quedarán ' + resto.toFixed(2) + ' qq en esa bodega.';
        ayudaPeso.classList.remove('ayuda-alerta');
    }

    /// Avisa cuando el precio queda por debajo del precio base: no lo
    /// impide, pero el trigger va a dejar una alerta en la bitacora.
    function revisarPrecio() {
        if (!ayudaPrecio) { return; }

        var base = numero(opcionLote(), 'data-base');
        var p = parseFloat(precio.value);

        if (base === null || isNaN(p) || p <= 0) {
            ayudaPrecio.textContent = 'Lo pactado con el comprador.';
            ayudaPrecio.classList.remove('ayuda-alerta');
            return;
        }

        if (p < base) {
            ayudaPrecio.textContent = 'Está ' + quetzales(base - p) +
                ' abajo del precio base: queda una alerta en la bitácora.';
            ayudaPrecio.classList.add('ayuda-alerta');
            return;
        }

        ayudaPrecio.textContent = p > base
            ? quetzales(p - base) + ' arriba del precio base.'
            : 'Igual al precio base de la temporada.';
        ayudaPrecio.classList.remove('ayuda-alerta');
    }

    function explicarForma() {
        if (!ayudaForma || !forma) { return; }

        ayudaForma.textContent = forma.value === 'Contado'
            ? 'El dinero entra al despachar.'
            : 'Queda pendiente de cobro: ' + forma.value.replace('Credito', 'crédito') + '.';
    }

    function contar() {
        if (!total || !detalle) { return; }

        var qq = parseFloat(peso.value);
        var p = parseFloat(precio.value);

        if (isNaN(qq) || isNaN(p) || qq <= 0 || p <= 0) {
            total.textContent = quetzales(0);
            detalle.textContent = 'Elija el lote, la cantidad y el precio.';
            return;
        }

        total.textContent = quetzales(qq * p);
        detalle.textContent = qq.toFixed(2) + ' qq × ' + quetzales(p) + ' por quintal' +
            (forma ? ' · ' + forma.options[forma.selectedIndex].textContent.trim() : '');
    }

    function actualizar() {
        revisarPeso();
        revisarPrecio();
        explicarForma();
        contar();
    }

    lote.addEventListener('change', function () {
        llenarFicha();
        filtrarBodegas();
        peso.value = '';
        actualizar();
    });

    bodega.addEventListener('change', actualizar);
    peso.addEventListener('input', actualizar);
    precio.addEventListener('input', actualizar);
    if (forma) { forma.addEventListener('change', actualizar); }

    // Al recargar, el navegador reescribe los campos: se vuelve a lo que
    // mando el servidor (en blanco al entrar, con los datos si hubo error).
    (function arrancarLimpio() {
        var form = lote.closest('form');
        if (!form) { return; }

        form.querySelectorAll('input, textarea').forEach(function (campo) {
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
    filtrarBodegas();
    actualizar();
})();
