// Ayuda del formulario de acopio: calcula la merma mientras se escribe el peso.
// La validacion de verdad la hace sp_registrar_acopio en la base; esto es solo
// para que el usuario vea la cifra antes de enviar.
(function () {
    'use strict';

    var lote = document.getElementById('lote');
    var peso = document.getElementById('peso');
    var ayuda = document.getElementById('ayuda-merma');
    if (!lote || !peso || !ayuda) { return; }

    var basico = ayuda.textContent;

    function cosechado() {
        var op = lote.options[lote.selectedIndex];
        var v = op ? parseFloat(op.getAttribute('data-peso')) : NaN;
        return isNaN(v) ? null : v;
    }

    function actualizar() {
        var bruto = cosechado();
        var recibido = parseFloat(peso.value);

        if (bruto === null) {
            ayuda.textContent = basico;
            ayuda.classList.remove('ayuda-alerta');
            return;
        }

        peso.max = bruto;

        if (isNaN(recibido) || recibido <= 0) {
            ayuda.textContent = 'Peso cosechado: ' + bruto.toFixed(2) + ' qq.';
            ayuda.classList.remove('ayuda-alerta');
            return;
        }

        if (recibido > bruto) {
            ayuda.textContent = 'El peso recibido supera los ' + bruto.toFixed(2) +
                ' qq cosechados: la base lo va a rechazar.';
            ayuda.classList.add('ayuda-alerta');
            return;
        }

        var merma = bruto - recibido;
        var pct = bruto > 0 ? (merma / bruto) * 100 : 0;
        ayuda.textContent = 'Merma de transporte: ' + merma.toFixed(2) + ' qq (' +
            pct.toFixed(2) + ' %).';
        ayuda.classList.toggle('ayuda-alerta', pct > 15);
    }

    lote.addEventListener('change', actualizar);
    peso.addEventListener('input', actualizar);
    actualizar();
})();
